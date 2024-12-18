# ---------------------------------------------------------------------------------------------------------------------
# TERRAGRUNT CONFIGURATION
# Terragrunt is a thin wrapper for Terraform/OpenTofu that provides extra tools for working with multiple modules,
# remote state, and locking: https://github.com/gruntwork-io/terragrunt
# ---------------------------------------------------------------------------------------------------------------------

locals {
  # Automatically load environment-level variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  host = local.environment_vars.locals.host
  client_certificate = local.environment_vars.locals.client_certificate
  client_key = local.environment_vars.locals.client_key
  cluster_ca_certificate = local.environment_vars.locals.cluster_ca_certificate
}

# Generate an AWS provider block
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "kubernetes" {
  host = "${local.host}"
  client_certificate     = base64decode("${local.client_certificate}")
  client_key             = base64decode("${local.client_key}")
  cluster_ca_certificate = base64decode("${local.cluster_ca_certificate}")
}
EOF
}

# Configure Terragrunt to automatically store tfstate files in kubernetes
remote_state {
  backend = "kubernetes"
  config = {
    secret_suffix    = "tfstate"
    namespace        = "terraform"
    config_path      = "~/.kube/config"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Configure what repos to search when you run 'terragrunt catalog'
catalog {
  urls = [
    "https://github.com/gruntwork-io/terragrunt-infrastructure-modules-example",
    "https://github.com/gruntwork-io/terraform-aws-utilities",
    "https://github.com/gruntwork-io/terraform-kubernetes-namespace"
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# GLOBAL PARAMETERS
# These variables apply to all configurations in this subfolder. These are automatically merged into the child
# `terragrunt.hcl` config via the include block.
# ---------------------------------------------------------------------------------------------------------------------

# Configure root level variables that all resources can inherit. This is especially helpful with multi-account configs
# where terraform_remote_state data sources are placed directly into the modules.
inputs = merge(
  local.environment_vars.locals,
)
