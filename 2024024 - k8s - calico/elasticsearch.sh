#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

echo "Installing Elasticsearch $(date "+%T")"
whoami
pwd

kubectl create -f https://download.elastic.co/downloads/eck/2.16.0/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/2.16.0/operator.yaml

kubectl wait pod -n elastic-system --all --for=condition=ready --timeout=300s

cat <<EOF | kubectl apply -f -
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: quickstart
  namespace: elastic-system
spec:
  version: 8.17.0
  nodeSets:
  - name: default
    count: 1
    config:
      node.store.allow_mmap: false
      http.cors.enabled: true
      http.cors.allow-origin: "*"
  http:
    service:
      spec:
        type: LoadBalancer
    tls:
      selfSignedCertificate:
        disabled: true
EOF

sleep 5
kubectl wait pod -n elastic-system --all --for=condition=ready --timeout=300s

kubectl get elasticsearch -n elastic-system
kubectl get pods --selector='elasticsearch.k8s.elastic.co/cluster-name=quickstart' -n elastic-system

ES_IP=$(kubectl get services --namespace elastic-system quickstart-es-http --output jsonpath='{.status.loadBalancer.ingress[0].ip}')
ES_PASSWORD=$(kubectl get secret quickstart-es-elastic-user -o go-template='{{.data.elastic | base64decode}}' -n elastic-system)

echo "Elasticsearch IP: $ES_IP"	
echo "Elasticsearch password: $ES_PASSWORD"

# cat <<EOF | kubectl apply -f -
# apiVersion: v1
# kind: Service
# metadata:
#   name: quickstart-es-lb
#   namespace: elastic-system
# spec:
#   selector:
#     common.k8s.elastic.co/type: elasticsearch
#     elasticsearch.k8s.elastic.co/cluster-name: quickstart
#   type: LoadBalancer
#   ports:
#   - name: https
#     protocol: TCP
#     port: 9200
#     targetPort: 9200
# EOF

#kubectl debug -it \
#--container=debug-container \
#--image=alpine \
#--target=elasticsearch quickstart-es-default-0 \
#--namespace=elastic-system \
#--profile=general

# clusterip = quickstart-es-http.elastic-system.svc.cluster.local

ES_VUE_CONFIG="[ { \"name\": \"quickstart\", \"uri\": \"http://$ES_IP:9200\", \"username\": \"elastic\", \"password\": \"$ES_PASSWORD\" } ]"
echo "Elasticsearch Vue config: $ES_VUE_CONFIG"

kubectl create configmap esvue-config --from-file=ELASTICVUE_CLUSTERS=<(echo $ES_VUE_CONFIG) -n elastic-system

echo "
apiVersion: apps/v1
kind: Deployment
metadata:
  name: elasticvue
  namespace: elastic-system
  labels:
    app: elasticvue
spec:
  replicas: 1
  selector:
    matchLabels:
      app: elasticvue
  template:
    metadata:
      labels:
        app: elasticvue
    spec:
      containers:
        - name: elasticvue
          image: cars10/elasticvue
          envFrom:
          - configMapRef:
              name: esvue-config
          ports:
          - name: http
            containerPort: 8080
" | kubectl apply -f -

echo "Elasticsearch installed $(date "+%T")"