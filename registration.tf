
resource "null_resource" "register" {

  triggers = {
    site                = local.cluster_name,
    tenant              = var.volterra_tenant
    token               = var.volterra_api_token
    size                = var.volterra_cluster_size,
    allow_ssl_tunnels   = var.volterra_ssl_tunnels ? "true" : "false"
    allow_ipsec_tunnels = var.volterra_ipsec_tunnels ? "true" : "false"
  }

  depends_on = [ibm_is_instance.volterra_ce_instance]

  provisioner "local-exec" {
    when        = create
    working_dir = "path.module"
    command     = "site_registration_actions.py --delay 30 --action 'registernodes' --site '${self.triggers.site}' --tenant '${self.triggers.tenant}' --token '${self.triggers.token}' --ssl ${self.triggers.allow_ssl_tunnels} --ipsec ${self.triggers.allow_ipsec_tunnels} --size ${self.triggers.size}"
    interpreter = ["python3"]
    on_failure  = continue
  }

  provisioner "local-exec" {
    when        = destroy
    working_dir = "path.module"
    command     = "site_registration_actions.py --action sitedelete --site '${self.triggers.site}' --tenant '${self.triggers.tenant}' --token '${self.triggers.token}'"
    interpreter = ["python3"]
    on_failure  = continue
  }
}

