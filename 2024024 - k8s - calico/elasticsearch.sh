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
  - name: master
    count: 1
    config:
      node.roles: ["master"]
      node.store.allow_mmap: false
      http.cors.enabled: true
      http.cors.allow-origin: "*"
  - name: ingest-data
    count: 2
    config:
      node.roles: ["data", "ingest"]
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

# set the number of replica to zero because the installation is not redudant. The inddices are show in yellow otherwise.
curl http://$ES_IP:9200/_template/template1 -s  -u elastic:$ES_PASSWORD -X PUT -H "Content-Type: application/json" -d @- << EOF
{
  "index_patterns": [
    "*"
  ],
  "order": 0,
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0
  }
}
EOF


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

cat <<EOF | kubectl apply -f -
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: kibana
  namespace: elastic-system
spec:
  version: 8.17.0
  count: 1
  elasticsearchRef:
    name: quickstart
EOF

#fluentd

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluentd
  namespace: elastic-system

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fluentd
rules:
- apiGroups:
  - ""
  resources:
  - pods
  - namespaces
  verbs:
  - get
  - list
  - watch

---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: fluentd
roleRef:
  kind: ClusterRole
  name: fluentd
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: fluentd
  namespace: elastic-system
EOF

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd
  namespace: elastic-system
  labels:
    k8s-app: fluentd-logging
    version: v1
spec:
  selector:
    matchLabels:
      k8s-app: fluentd-logging
      version: v1
  template:
    metadata:
      labels:
        k8s-app: fluentd-logging
        version: v1
    spec:
      serviceAccount: fluentd
      serviceAccountName: fluentd
      tolerations:
      - key: node-role.kubernetes.io/control-plane
        effect: NoSchedule
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      containers:
      - name: fluentd
        image: fluent/fluentd-kubernetes-daemonset:v1-debian-elasticsearch8
        env:
          - name: K8S_NODE_NAME
            valueFrom:
              fieldRef:
                fieldPath: spec.nodeName
          - name:  FLUENT_ELASTICSEARCH_HOST
            value: "quickstart-es-http.elastic-system.svc.cluster.local"
          - name:  FLUENT_ELASTICSEARCH_PORT
            value: "9200"
          - name: FLUENT_ELASTICSEARCH_SCHEME
            value: "http"
          # Option to configure elasticsearch plugin with self signed certs
          # ================================================================
          - name: FLUENT_ELASTICSEARCH_SSL_VERIFY
            value: "true"
          # Option to configure elasticsearch plugin with tls
          # ================================================================
          - name: FLUENT_ELASTICSEARCH_SSL_VERSION
            value: "TLSv1_2"
          # X-Pack Authentication
          # =====================
          - name: FLUENT_ELASTICSEARCH_USER
            value: "elastic"
          - name: FLUENT_ELASTICSEARCH_PASSWORD
            value: "$ES_PASSWORD"
          - name: FLUENT_CONTAINER_TAIL_EXCLUDE_PATH
            value: /var/log/containers/fluent*
          - name: FLUENT_CONTAINER_TAIL_PARSER_TYPE
            value: /^(?<time>.+) (?<stream>stdout|stderr)( (?<logtag>.))? (?<log>.*)$/
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        # When actual pod logs in /var/lib/docker/containers, the following lines should be used.
        # - name: dockercontainerlogdirectory
        #   mountPath: /var/lib/docker/containers
        #   readOnly: true
        # When actual pod logs in /var/log/pods, the following lines should be used.
        - name: dockercontainerlogdirectory
          mountPath: /var/log/pods
          readOnly: true
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      # When actual pod logs in /var/lib/docker/containers, the following lines should be used.
      # - name: dockercontainerlogdirectory
      #   hostPath:
      #     path: /var/lib/docker/containers
      # When actual pod logs in /var/log/pods, the following lines should be used.
      - name: dockercontainerlogdirectory
        hostPath:
          path: /var/log/pods
EOF


echo "Elasticsearch installed $(date "+%T")"