#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

echo "Installing argocd"
whoami
pwd

kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl wait deployment -n argocd --all --for condition=Available=True --timeout=300s

echo "Argocd admin password: $(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)" 
echo "argocd installed $(date "+%T")"
