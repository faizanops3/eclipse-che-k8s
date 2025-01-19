#!/bin/bash

echo "kubeadm config images pull..."
kubeadm config images pull

sudo kubeadm init --pod-network-cidr=10.244.0.0/16

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config



kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/calico.yaml


# systemctl restart containerd
# systemctl restart kubelet

kubectl taint nodes "$(hostname)" node-role.kubernetes.io/control-plane:NoSchedule-
