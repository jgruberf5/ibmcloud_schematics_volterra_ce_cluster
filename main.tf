data "ibm_resource_group" "group" {
  name = var.resource_group
}

# create a random password if we need it
resource "random_password" "admin_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "random_uuid" "namer" {}

locals {
  # user admin_password if supplied, else set a random password
  admin_password = var.admin_password == "" ? random_password.admin_password.result : var.admin_password
  # because someone can't spell in the /etc/vpm/certified-hardware.yaml file in the qcow2 image
  certified_hardware_map = {
    voltstack = ["kvm-volstack-combo", "kvm-multi-nic-voltstack-combo"],
    voltmesh  = ["kvm-voltmesh", "kvm-multi-nic-voltmesh"]
  }
  profile_map = {
    voltstack = "bx2-4x16",
    voltmesh  = "cx2-4x8"
  }
  template_map = {
    voltstack = "${path.module}/volterra_voltstack_ce.yaml",
    voltmesh  = "${path.module}/volterra_voltmesh_ce.yaml"
  }
  vpc_gen2_region_location_map = {
    "au-syd" = {
      "latitude"  = "-33.8688",
      "longitude" = "151.2093"
    },
    "ca-tor" = {
      "latitude"  = "43.6532",
      "longitude" = "-79.3832"
    },
    "eu-de" = {
      "latitude"  = "50.1109",
      "longitude" = "8.6821"
    },
    "eu-gb" = {
      "latitude"  = "51.5074",
      "longitude" = "0.1278"
    },
    "jp-osa" = {
      "latitude"  = "34.6937",
      "longitude" = "135.5023"
    },
    "jp-tok" = {
      "latitude"  = "35.6762",
      "longitude" = "139.6503"
    },
    "us-east" = {
      "latitude"  = "38.9072",
      "longitude" = "-77.0369"
    },
    "us-south" = {
      "latitude"  = "32.7924",
      "longitude" = "-96.8147"
    }
  }
  which_stack        = var.voltstack ? "voltstack" : "voltmesh"
  inside_nic         = var.voltstack ? "eth0" : "eth1"
  secondary_subnets  = var.inside_subnet_id == "" ? compact(list("")) : compact(list(var.inside_subnet_id))
  certified_hardware = element(local.certified_hardware_map[local.which_stack].*, 1)
  ce_profile         = local.profile_map[local.which_stack]
  template_file      = file(local.template_map[local.which_stack])
  create_fip_count   = var.ipsec_tunnels ? var.cluster_size : 0
  cluster_masters    = var.cluster_size > 2 ? 3 : 1
}

# lookup compute profile by name
data "ibm_is_instance_profile" "instance_profile" {
  name = local.ce_profile
}

resource "local_file" "complete_flag" {
  filename   = "${path.module}/complete.flag"
  content    = uuid()
  depends_on = [null_resource.site_registration]
}

resource "null_resource" "site" {
  triggers = {
    tenant          = var.tenant
    token           = var.api_token
    site_name       = var.site_name
    fleet_label     = var.fleet_label
    voltstack       = var.voltstack ? "true" : "false"
    cluster_size    = var.cluster_size,
    latitude        = lookup(local.vpc_gen2_region_location_map, var.region).latitude
    longitude       = lookup(local.vpc_gen2_region_location_map, var.region).longitude
    inside_networks = jsonencode(var.inside_networks)
    inside_gateway  = var.inside_gateway
    consul_servers  = jsonencode(var.consul_https_servers)
    ca_cert_encoded = base64encode(var.consul_ca_cert)
    # always force update
    timestamp       = timestamp()
  }

  provisioner "local-exec" {
    when       = create
    command    = "${path.module}/volterra_resource_site_create.py --site '${self.triggers.site_name}' --fleet '${self.triggers.fleet_label}' --tenant '${self.triggers.tenant}' --token '${self.triggers.token}' --voltstack '${self.triggers.voltstack}' --k8sdomain '${self.triggers.site_name}.infra' --cluster_size  '${self.triggers.cluster_size}' --latitude '${self.triggers.latitude}' --longitude '${self.triggers.longitude}' --inside_networks '${self.triggers.inside_networks}' --inside_gateway '${self.triggers.inside_gateway}' --consul_servers '${self.triggers.consul_servers}' --ca_cert_encoded '${self.triggers.ca_cert_encoded}'"
    on_failure = fail
  }

  provisioner "local-exec" {
    when       = destroy
    command    = "${path.module}/volterra_resource_site_destroy.py --site '${self.triggers.site_name}' --fleet '${self.triggers.fleet_label}' --tenant '${self.triggers.tenant}' --token '${self.triggers.token}' --voltstack '${self.triggers.voltstack}'"
    on_failure = fail
  }
}

data "local_file" "site_token" {
    filename = "${path.module}/${var.site_name}_site_token.txt"
    depends_on = [null_resource.site]
}


data "template_file" "user_data" {
  template = local.template_file
  vars = {
    admin_password     = local.admin_password
    cluster_name       = var.site_name
    fleet_label        = var.fleet_label
    certified_hardware = local.certified_hardware
    latitude           = lookup(local.vpc_gen2_region_location_map, var.region).latitude
    longitude          = lookup(local.vpc_gen2_region_location_map, var.region).longitude
    site_token         = data.local_file.site_token.content
    profile            = local.ce_profile
    inside_nic         = local.inside_nic
    region             = var.region
  }
  depends_on = [data.local_file.site_token]
}

# create compute instance
resource "ibm_is_instance" "ce_instance" {
  count          = var.cluster_size
  name           = "${var.site_name}-vce-${count.index}"
  resource_group = data.ibm_resource_group.group.id
  image          = ibm_is_image.ce_custom_image.id
  profile        = data.ibm_is_instance_profile.instance_profile.id
  primary_network_interface {
    name              = "outside"
    subnet            = var.outside_subnet_id
    security_groups   = [var.security_group_id]
    allow_ip_spoofing = true
  }
  dynamic "network_interfaces" {
    for_each = local.secondary_subnets
    content {
      name              = "inside"
      subnet            = network_interfaces.value
      security_groups   = [var.security_group_id]
      allow_ip_spoofing = true
    }
  }
  vpc       = var.vpc
  zone      = var.zone
  keys      = [var.ssh_key_id]
  user_data = data.template_file.user_data.rendered
  timeouts {
    create = "60m"
    delete = "120m"
  }
  depends_on = [data.local_file.site_token]
}

resource "ibm_is_floating_ip" "external_floating_ip" {
  count          = local.create_fip_count
  name           = "fip-${var.site_name}-vce-${count.index}"
  resource_group = data.ibm_resource_group.group.id
  target         = element(ibm_is_instance.ce_instance.*.primary_network_interface.0.id, count.index)
}

resource "null_resource" "site_registration" {

  triggers = {
    site                = var.site_name,
    tenant              = var.tenant
    token               = var.api_token
    size                = local.cluster_masters,
    allow_ssl_tunnels   = var.ssl_tunnels ? "true" : "false"
    allow_ipsec_tunnels = var.ipsec_tunnels ? "true" : "false"
    voltstack           = var.voltstack ? "true" : "false"
  }

  depends_on = [ibm_is_instance.ce_instance]

  provisioner "local-exec" {
    when       = create
    command    = "${path.module}/volterra_site_registration_actions.py --delay 60 --action 'registernodes' --site '${self.triggers.site}' --tenant '${self.triggers.tenant}' --token '${self.triggers.token}' --ssl ${self.triggers.allow_ssl_tunnels} --ipsec ${self.triggers.allow_ipsec_tunnels} --size ${self.triggers.size} --voltstack '${self.triggers.voltstack}'"
    on_failure = fail
  }

}