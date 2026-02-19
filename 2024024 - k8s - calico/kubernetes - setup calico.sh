#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

echo "Setting up kubernetes CNI calico $(date "+%T")"
whoami
pwd

echo "Installing custom resources $(date "+%T")"
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.3/manifests/operator-crds.yaml

echo "Installing operator $(date "+%T")"
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.31.3/manifests/tigera-operator.yaml

echo "Installing ip tables custom resources $(date "+%T")"
curl https://raw.githubusercontent.com/projectcalico/calico/v3.31.3/manifests/custom-resources.yaml -O
sed -i 's/192.168.0.0\/16/10.244.0.0\/16/g' custom-resources.yaml
kubectl create -f custom-resources.yaml


echo "Waiting calico is installed"
sleep 30 # we first sleep because the namespace are not yet created for checking the status.
kubectl wait --timeout 180s --for=condition=Available tigerastatus --all
kubectl get tigerastatus
kubectl get tigerastatus -o yaml

kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

echo "Installed kubernetes CNI calico $(date "+%T")"
