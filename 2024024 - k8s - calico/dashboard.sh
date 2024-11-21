#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

echo "Installing Dashboard"
whoami
pwd

helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard

kubectl apply -f /vagrant_data/kubernetes/dashboard/admin-user.yaml
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')
