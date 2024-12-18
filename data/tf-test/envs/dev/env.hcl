locals {
  environment = "dev"
  host = get_env("TF_VAR_host")
  client_certificate = get_env("TF_VAR_client_certificate")
  client_key = get_env("TF_VAR_client_key")
  cluster_ca_certificate = get_env("TF_VAR_cluster_ca_certificate")
}
