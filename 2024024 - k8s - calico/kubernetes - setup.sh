#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

echo "Setting up kubernetes $(date "+%T")"
whoami
pwd

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
chmod 644 /etc/apt/sources.list.d/kubernetes.list   # helps tools such as command-not-found to work correctly

apt-get update -y
apt-get install -y kubelet kubeadm kubectl kubernetes-cni
apt-mark hold kubelet kubeadm kubectl kubernetes-cni
		
tee /etc/modules-load.d/k8s.conf<<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

echo '1' > /proc/sys/net/ipv4/ip_forward
		
tee /etc/sysctl.d/k8s.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get remove containerd 
apt-get update
apt-get install -y containerd.io

rm /etc/containerd/config.toml
containerd config default | tee /etc/containerd/config.toml
sed -i 's/pause:3.8/pause:3.10/g' /etc/containerd/config.toml

sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml
			
systemctl restart containerd
		
# ctr plugins ls

systemctl enable kubelet
kubeadm config images pull
kubeadm init --pod-network-cidr=10.244.0.0/16
kubeadm config images pull

# configure for root user
mkdir -p "$HOME"/.kube
cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config

# allow to run pod on the control plane because we are in a testing environmnet.
kubectl taint nodes k8s-masternode node-role.kubernetes.io/control-plane-

systemctl restart containerd
systemctl restart kubelet

mkdir -p /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown 1000:1000 /home/vagrant/.kube/config
cp /etc/kubernetes/admin.conf /vagrant_data/.kube/config

echo "Installed kubernetes $(date "+%T")"
