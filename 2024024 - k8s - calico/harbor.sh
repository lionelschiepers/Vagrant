#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

echo "Installing Harbor"
whoami
pwd

helm repo add harbor https://helm.goharbor.io
helm repo update

# https://vishynit.medium.com/setting-up-harbor-registry-on-kubernetes-using-helm-chart-5989d7c8df2a
#helm install harbor harbor/harbor --create-namespace --namespace harbor --wait --timeout 10m \
# --set harborAdminPassword=password \
# --set externalURL=http://$(ip address show eth0 | grep 'inet ' | sed -e 's/^.*inet //' -e 's/\/.*$//' | tr -d '\n') \

helm install harbor harbor/harbor --create-namespace --namespace harbor --wait --timeout 10m \
 --set harborAdminPassword=password \
 --set externalURL=http://$(ip address show eth0 | grep 'inet ' | sed -e 's/^.*inet //' -e 's/\/.*$//' | tr -d '\n'):30002 \
 --set expose.type=nodePort \
 --set expose.tls.enabled=false

# export PROXY_IP=$(kubectl get svc --namespace kong kong-gateway-proxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
# echo $PROXY_IP

echo "
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: harbor
  annotations:
    konghq.com/strip-path: 'false'
spec:
  parentRefs:
  - name: kong
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /c
    backendRefs:
    - name: harbor-core
      namespace: harbor
      kind: Service
      port: 80
  - backendRefs:
    - name: harbor-portal
      namespace: harbor
      kind: Service
      port: 80
" | kubectl apply -f -

echo "
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: harbor-portal
  namespace: harbor
spec:
  from:
  - group: gateway.networking.k8s.io
    namespace: default
    kind: HTTPRoute
  to:
  - group: \"\"
    kind: Service
    name: harbor-portal
" | kubectl apply -f -

# helm repo add jetstack https://charts.jetstack.io
# helm repo update


# helm install \
#  cert-manager jetstack/cert-manager \
#  --namespace cert-manager \
#  --create-namespace \
#  --version v1.16.2 \
#  --set crds.enabled=true \
#  --wait --timeout 2m

echo "Finished Harbor"
