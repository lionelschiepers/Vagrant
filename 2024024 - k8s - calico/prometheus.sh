#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

echo "Installing Prometheus"
whoami
pwd

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
#helm install prometheus prometheus-community/prometheus
helm install prometheus-stack prometheus-community/kube-prometheus-stack

#kubectl create namespace monitoring
#kubectl create -f /vagrant_data/kubernetes/prometheus/clusterRole.yaml
#kubectl create -f /vagrant_data/kubernetes/prometheus/config-map.yaml
#kubectl create -f /vagrant_data/kubernetes/prometheus/prometheus-deployment.yaml

#echo "Waiting deployment is finished"
#kubectl wait deployment -n monitoring prometheus-deployment --for condition=Available=True --timeout=120s

# kubectl get deployments --namespace=monitoring
# kubectl get pods --namespace=monitoring

# kubectl get all --all-namespaces
# kubectl cluster-info

#kubectl create -f /vagrant_data/kubernetes/prometheus/prometheus-service.yaml --namespace=monitoring
#kubectl get services -n monitoring
echo "Prometheus installed"
