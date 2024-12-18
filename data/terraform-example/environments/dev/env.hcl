locals {
  environment = "dev"
  host = get_env("host")
  client_certificate = get_env("client_certificate")
  client_key = get_env("client_key")
  cluster_ca_certificate = get_env("cluster_ca_certificate")
}
