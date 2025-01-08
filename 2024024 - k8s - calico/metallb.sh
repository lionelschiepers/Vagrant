#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

echo "Installing Metallb $(date "+%T")"
whoami
pwd

kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl apply -f - -n kube-system


helm repo add metallb https://metallb.github.io/metallb
helm upgrade --install metallb metallb/metallb --create-namespace --namespace metallb-system --wait --timeout 2m \
 --set prometheus.namespace=prometheus \
 --set speaker.ignoreExcludeLB=true

kubectl wait deployment -n metallb-system --all --for condition=Available=True --timeout=300s

echo "
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.124.240-192.168.124.250
" | kubectl apply -f -

echo "
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default-pool
" | kubectl apply -f -

# demo server
# kubectl create deployment hello-server --image=gcr.io/google-samples/hello-app:1.0
# kubectl expose deployment hello-server --type LoadBalancer --port 80 --target-port 8080


echo "Installed Metallb $(date "+%T")"
