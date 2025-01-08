#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

echo "Installing Kong"
whoami
pwd

# https://docs.konghq.com/kubernetes-ingress-controller/latest/get-started/
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

echo "
---
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: kong
  annotations:
    konghq.com/gatewayclass-unmanaged: 'true'

spec:
  controllerName: konghq.com/kic-gateway-controller
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: kong
spec:
  gatewayClassName: kong
  listeners:
  - name: proxy
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: All
" | kubectl apply -f -


# https://medium.com/@martin.hodges/using-kong-to-access-kubernetes-services-using-a-gateway-resource-with-no-cloud-provided-8a1bcd396be9
helm repo add kong https://charts.konghq.com
helm repo update
echo "installing kong at $(date "+%T")"
helm install kong kong/ingress -n kong --create-namespace \
 --set gateway.admin.http.enabled=true \
# --set gateway.proxy.type=NodePort \
# --set gateway.proxy.http.enabled=true \
# --set gateway.proxy.http.nodePort=32001 \
# --set gateway.proxy.tls.enabled=false 

# assign the external ip address because k8s doesn't support external ip for the load balancer. This is a workaround
# to access the load balancer from the host ip.
kubectl patch svc kong-gateway-proxy -n kong -p "{\"spec\": {\"type\": \"LoadBalancer\", \"externalIPs\":[\"$(ip address show eth0 | grep 'inet ' | sed -e 's/^.*inet //' -e 's/\/.*$//' | tr -d '\n')\"]}}"
kubectl patch --type=json gateways.gateway.networking.k8s.io kong -p='[{"op":"replace","path": "/spec/listeners/0/allowedRoutes/namespaces/from","value":"All"}]'

kubectl get svc --namespace kong kong-gateway-proxy

kubectl wait deployment -n kong --all --for condition=Available=True --timeout=300s
echo "installed at $(date "+%T")"

echo "Finished Kong"
