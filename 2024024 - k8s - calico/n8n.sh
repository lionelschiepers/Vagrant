#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

echo "Installing n8n $(date "+%T")"
whoami
pwd

#see https://github.com/n8n-io/n8n-hosting/blob/main/kubernetes/n8n-deployment.yaml
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: n8n
EOF

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  labels:
    service: n8n-pvclaim0
  name: n8n-pvclaim0
  namespace: n8n
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
EOF

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    service: n8n
  name: n8n
  namespace: n8n
spec:
  replicas: 1
  selector:
    matchLabels:
      service: n8n
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        service: n8n
    spec:
      initContainers:
        - name: volume-permissions
          image: busybox:1.36
          command: ["sh", "-c", "chown 1000:1000 /data"]
          volumeMounts:
            - name: n8n-pvclaim0
              mountPath: /data
      containers:
        - command:
            - /bin/sh
          args:
            - -c
            - sleep 5; n8n start
          env:
#            - name: DB_TYPE
#              value: postgresdb
#            - name: DB_POSTGRESDB_HOST
#              value: postgres-service.n8n.svc.cluster.local
#            - name: DB_POSTGRESDB_PORT
#              value: "5432"
#            - name: DB_POSTGRESDB_DATABASE
#              value: n8n
#            - name: DB_POSTGRESDB_USER
#              valueFrom:
#                secretKeyRef:
#                  name: postgres-secret
#                  key: POSTGRES_NON_ROOT_USER
#            - name: DB_POSTGRESDB_PASSWORD
#              valueFrom:
#                secretKeyRef:
#                  name: postgres-secret
#                  key: POSTGRES_NON_ROOT_PASSWORD
            - name: N8N_PROTOCOL
              value: http
            - name: N8N_PORT
              value: "5678"
          image: n8nio/n8n
          name: n8n
          ports:
            - containerPort: 5678
          resources:
            requests:
              memory: "250Mi"
            limits:
              memory: "500Mi"
          volumeMounts:
            - mountPath: /home/node/.n8n
              name: n8n-pvclaim0
      restartPolicy: Always
      volumes:
        - name: n8n-pvclaim0
          persistentVolumeClaim:
            claimName: n8n-pvclaim0
#        - name: n8n-secret
#          secret:
#            secretName: n8n-secret
#        - name: postgres-secret
#          secret:
#            secretName: postgres-secret
EOF

echo "n8n installed $(date "+%T")"