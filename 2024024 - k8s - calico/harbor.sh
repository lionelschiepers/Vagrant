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

apt-get install -y docker-ce docker-ce-cli jq
# mkdir /etc/docker 2>/dev/null

# if test -f /etc/default/docker; then
#   echo "DOCKER_OPTS=\"--config-file=/etc/docker/daemon.json\"" > /etc/default/docker
# fi

# if test -f /etc/docker/daemon.json; then
#   echo "{
#   \"insecure-registries\":[\"$(ip address show eth0 | grep 'inet ' | sed -e 's/^.*inet //' -e 's/\/.*$//' | tr -d '\n'):30002\"]
# }" > /etc/docker/daemon.json
# fi


# cat /etc/docker/daemon.json | jq '.insecure-registries += ["192.168.124.171:30002"]'

# create a test project in harbor
echo '{
    "project_name": "test",
    "public": true,
    "metadata": {
      "public": "true",
      "enable_content_trust": "false",
      "enable_content_trust_cosign": "false"
    },
    "storage_limit": 0
  }' | curl -s -o /tmp/result -u "admin:password" -H 'accept: application/json' -H 'Content-Type: application/json' --data-binary @- -X POST http://$(ip address show eth0 | grep 'inet ' | sed -e 's/^.*inet //' -e 's/\/.*$//' | tr -d '\n'):30002/api/v2.0/projects


docker image pull debian
docker image tag debian:latest 127.0.0.1:30002/test/debian:latest

docker login 127.0.0.1:30002 -u=admin -p=password
docker image push 127.0.0.1:30002/test/debian:latest

echo "Finished Harbor"
