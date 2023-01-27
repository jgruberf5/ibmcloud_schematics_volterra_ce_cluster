##################################################################################
# resource_group - The IBM Cloud resource group to create the VPC
##################################################################################
variable "resource_group" {
  type        = string
  default     = "default"
  description = "The IBM Cloud resource group to create the VPC"
}

##################################################################################
# region - The IBM Cloud VPC Gen 2 region to create VPC environment
##################################################################################
variable "region" {
  default     = "us-south"
  description = "The IBM Cloud VPC Gen 2 region to create VPC environment"
}

##################################################################################
# zone - The zone within the IBM Cloud region to create the VPC environment
##################################################################################
variable "zone" {
  default     = ""
  description = "The zone within the IBM Cloud region to create the VPC environment"
}

##################################################################################
# download_region - The VPC region to Download the Public COS Images
##################################################################################
variable "download_region" {
  type        = string
  default     = "us-south"
  description = "The VPC region to Download the Public COS Images"
}

##################################################################################
# version - The version of Volterra CE image to Import
##################################################################################
variable "ce_version" {
  type        = string
  default     = "7.2009.5"
  description = "The version of Volterra CE image to Import"
}

##################################################################################
# vpc - The vpc ID within the IBM Cloud region to create the VPC environment
##################################################################################
variable "vpc" {
  default     = ""
  description = "The vpc ID within the IBM Cloud region to create the VPC environment"
}

##################################################################################
# ssh_key_id - The ID of the existing SSH key to inject into infrastructure
##################################################################################
variable "ssh_key_id" {
  default = ""
  description = "The ID of the existing SSH key to inject into infrastructure"
}

##################################################################################
# security_group_id - The VPC security group ID to connect the Consul cluster 
##################################################################################
variable "security_group_id" {
  default = ""
  description = "The VPC security group ID to connect the Consul cluster"
}

##################################################################################
# tenant - The Volterra tenant (group) name
##################################################################################
variable "tenant" {
  type        = string
  default     = ""
  description = "The Volterra tenant (group) name"
}

##################################################################################
# site_name - The Volterra Site name for this VPC
##################################################################################
variable "site_name" {
  type        = string
  default     = ""
  description = "The Volterra Site name for this VPC"
}

##################################################################################
# fleet_label - The Volterra Fleet label for this VPC
##################################################################################
variable "fleet_label" {
  type        = string
  default     = ""
  description = "The Volterra Fleet label for this VPC"
}

##################################################################################
# api_token - The API token to use to register with Volterra
##################################################################################
variable "api_token" {
  type        = string
  default     = ""
  description = "The API token to use to register with Volterra"
}

##################################################################################
# cluster_size - The Volterra cluster size
##################################################################################
variable "cluster_size" {
  type        = number
  default     = 3
  description = "The Volterra cluster size"
}

##################################################################################
# voltstack - Create Voltstack Site
##################################################################################
variable "voltstack" {
  type        = bool
  default     = false
  description = "Create Voltstack Site"
}

##################################################################################
# admin_password - The password for the built-in admin Volterra user
##################################################################################
variable "admin_password" {
  type        = string
  default     = ""
  description = "The password for the built-in admin Volterra user"
}

##################################################################################
# ssl_tunnels - Use SSL tunnels to connect to Volterra
##################################################################################
variable "ssl_tunnels" {
  type        = bool
  default     = false
  description = "Use SSL tunnels to connect to Volterra"
}

##################################################################################
# ipsec_tunnels - Use IPSEC tunnels to connect to Volterra
##################################################################################
variable "ipsec_tunnels" {
  type        = bool
  default     = true
  description = "Use IPSEC tunnels to connect to Volterra"
}

##################################################################################
# outside_subnet_id - Outside VPC subnet ID
##################################################################################
variable "outside_subnet_id" {
  type = string
  default = ""
  description = "Outside VPC subnet ID"
}

##################################################################################
# inside_subnet_id - Inside VPC subnet ID
##################################################################################
variable "inside_subnet_id" {
  type = string
  default = ""
  description = "Inside VPC subnet ID"
}

##################################################################################
# inside_gateway - Inside VPC subnet gateway
##################################################################################
variable "inside_gateway" {
  type = string
  default = ""
  description = "Inside VPC subnet gateway"
}

##################################################################################
# inside_networks - Inside reachable network IPv4 CIDRs
##################################################################################
variable "inside_networks" {
  type = list(string)
  default = [ ]
  description = "Inside reachable network IPv4 CIDRs"
}

##################################################################################
# consul_ca_cert - The CA certificate to register Consul service discovery
##################################################################################
variable "consul_ca_cert" {
  type = string
  default = ""
  description = "The CA certificate to register Consul service discovery"
}

##################################################################################
# consul_https_servers - The Consul servers to register with Consul service discovery
##################################################################################
variable "consul_https_servers" {
  type = list(string)
  default = []
  description = "The Consul servers to register with Consul service discovery"
}