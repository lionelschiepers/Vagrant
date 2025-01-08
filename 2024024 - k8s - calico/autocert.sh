#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

echo "Installing autocert"
whoami
pwd

wget https://dl.smallstep.com/cli/docs-ca-install/latest/step-cli_amd64.deb
sudo dpkg -i step-cli_amd64.deb

wget https://dl.smallstep.com/certificates/docs-ca-install/latest/step-ca_amd64.deb
sudo dpkg -i step-ca_amd64.deb

echo abc > capwd.txt
step ca init --deployment-type=standalone --name=Licaya --dns=localhost --address=:8443 --provisioner=ls@toto.com --password-file=capwd.txt
step certificate fingerprint .step/certs/root_ca.crt

step ca provisioner add acme -type ACME
sudo step-ca .step/config/ca.json --password-file capwd.txt &
sudo bash -c "step-ca .step/config/ca.json --password-file <(echo -n "abc")" &

step ca root root.crt -f
step ca certificate localhost srv.crt srv.key --password-file capwd.txt -f 

#or
 step certificate create --csr foo.example.com foo.csr foo.key
 step ca sign foo.csr foo.crt

#acme
step ca certificate --provisioner acme example.com example.crt example.key


# helm repo add smallstep https://smallstep.github.io/helm-charts/
# helm repo update
# helm install step-certificates smallstep/step-certificates

# https://github.com/smallstep/autocert 

helm repo add smallstep https://smallstep.github.io/helm-charts/
helm repo update
helm install autocert smallstep/autocert -n autocert --create-namespace

kubectl wait deployment -n autocert --all --for condition=Available=True --timeout=300s
kubectl -n default logs job.batch/autocert

echo "autocert installed"
