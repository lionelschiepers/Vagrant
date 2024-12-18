#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

echo "Installing Terraform"
whoami
pwd

wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
apt-get update -y
apt-get install -y terraform
snap install yq

https://blog.gruntwork.io/how-to-manage-multiple-environments-with-terraform-using-terragrunt-2c3e32fc60a8
snap install terragrunt

#https://medium.com/@vinoji2005/using-terraform-with-kubernetes-a-comprehensive-guide-237f6bbb0586

kubectl create namespace terraform

tf_host=$(kubectl config view --minify --flatten | yq -r .clusters[0].cluster.server -)
tf_client_certificate=$(kubectl config view --minify --flatten | yq -r .users[0].user.client-certificate-data -)
tf_client_key=$(kubectl config view --minify --flatten | yq -r .users[0].user.client-key-data -)
tf_cluster_ca_certificate=$(kubectl config view --minify --flatten | yq -r .clusters[0].cluster.certificate-authority-data -)

export TF_VAR_host="$tf_host"
export TF_VAR_client_certificate="$tf_client_certificate"
export TF_VAR_client_key="$tf_client_key"
export TF_VAR_cluster_ca_certificate="$tf_cluster_ca_certificate"

cat << EOF > backend.tf
terraform {
  backend "kubernetes" {
    secret_suffix    = "tfstate"
    namespace        = "terraform"
    config_path      = "~/.kube/config"
  }
}
EOF

cat << EOF > main.tf
terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

provider "kubernetes" {
  host = var.host
  client_certificate     = base64decode(var.client_certificate)
  client_key             = base64decode(var.client_key)
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
}
EOF

cat << EOF > variables.tf
variable "host" {
  type = string
}

variable "client_certificate" {
  type = string
}

variable "client_key" {
  type = string
}

variable "cluster_ca_certificate" {
  type = string
}
EOF

cat << EOF > terraform.tfvars
host                   = "$tf_host"
client_certificate     = "$tf_client_certificate"
client_key             = "$tf_client_key"
cluster_ca_certificate = "$tf_cluster_ca_certificate"
EOF

terraform init

cat << EOF >> nginx-example.tf
resource "kubernetes_namespace" "nginx" {
  metadata {
    name = "terraform-example"
  }
}

resource "kubernetes_deployment" "nginx" {
  metadata {
    name = "nginx-example"
    namespace = "terraform-example" 
    labels = {
      App = "ScalableNginxExample"
    }
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        App = "ScalableNginxExample"
      }
    }
    template {
      metadata {
        labels = {
          App = "ScalableNginxExample"
        }
      }
      spec {
        container {
          image = "nginx:1.27.3"
          name  = "example"

          port {
            container_port = 80
          }

          resources {
            limits = {
              cpu    = "0.5"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "50Mi"
            }
          }
        }
      }
    }
  }
}
EOF

terraform apply -auto-approve

echo "Finished Terraform"
