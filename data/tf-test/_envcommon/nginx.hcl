locals {
  # Automatically load environment-level variables
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  # Extract out common variables for reuse
  env = local.environment_vars.locals.environment

  # Expose the base source URL so different versions of the module can be deployed in different environments. This will
  # be used to construct the source URL in the child terragrunt configurations.
  # base_source_url = "git::git@github.com:gruntwork-io/terragrunt-infrastructure-modules-example.git//modules/mysql"
}

# ---------------------------------------------------------------------------------------------------------------------
# MODULE PARAMETERS
# These are the variables we have to pass in to use the module. This defines the parameters that are common across all
# environments.
# ---------------------------------------------------------------------------------------------------------------------
inputs = {
  name              = "mysql_${local.env}"

  # TODO: To avoid storing your DB password in the code, set it as the environment variable TF_VAR_master_password
}
