#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

echo "Installing KeyCloak"
whoami
pwd

#kubectl create -f https://raw.githubusercontent.com/keycloak/keycloak-quickstarts/latest/kubernetes/keycloak.yaml

echo "
apiVersion: v1
kind: Namespace
metadata:
  name: keycloak
" | kubectl apply -f -


echo "
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
  namespace: keycloak
  labels:
    app: keycloak
spec:
  replicas: 1
  selector:
    matchLabels:
      app: keycloak
  template:
    metadata:
      labels:
        app: keycloak
    spec:
      containers:
        - name: keycloak
          image: quay.io/keycloak/keycloak:26.0.7
          args: ["start-dev"]
          env:
            - name: KEYCLOAK_ADMIN
              value: admin
            - name: KEYCLOAK_ADMIN_PASSWORD
              value: admin
            - name: KC_PROXY
              value: edge
            - name: KC_METRICS_ENABLED
              value: \"true\"
            - name: KC_HEALTH_ENABLED
              value: \"true\"
          ports:
          - name: http
            containerPort: 8080
#          readinessProbe:
#            httpGet:
#              path: /health/ready
#              port: 9000
" | kubectl apply -f -


kubectl wait deployment -n keycloak keycloak --for condition=Available=True --timeout=120s

echo "Finished Keycloak"
