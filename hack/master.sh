#!/bin/bash
set -eu

HCLOUD_TOKEN=$1
HCLOUD_NETWORK_ID=$2

# Setup cluster
kubeadm config images pull

# see https://stackoverflow.com/a/62320297/3594403
IP_ADR=`ifconfig ens10 | grep -w "inet" | tr -s " " | cut -f3 -d" "`

kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --kubernetes-version=v1.19.0 \
  --ignore-preflight-errors=NumCPU \
  --apiserver-cert-extra-sans $IP_ADR

# Setup master components
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: hcloud
  namespace: kube-system
stringData:
  token: "$HCLOUD_TOKEN"
  network: "$HCLOUD_NETWORK_ID"
---
apiVersion: v1
kind: Secret
metadata:
  name: hcloud-csi
  namespace: kube-system
stringData:
  token: "$HCLOUD_TOKEN"
EOF

# Deploy Hetzner Cloud Controller Manager
kubectl apply -f https://raw.githubusercontent.com/hetznercloud/hcloud-cloud-controller-manager/5162e2f8bf9c38f4fdd632c81b847722d272fff8/deploy/ccm-networks.yaml

# Setup Cluster Network Interface (CNI)
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/v0.12.0/Documentation/kube-flannel.yml

# Tolerate taints introduced by external cloud provider flag for critical pods
kubectl -n kube-system patch daemonset kube-flannel-ds-amd64 --type json -p '[{"op":"add","path":"/spec/template/spec/tolerations/-","value":{"key":"node.cloudprovider.kubernetes.io/uninitialized","value":"true","effect":"NoSchedule"}}]'
kubectl -n kube-system patch deployment coredns --type json -p '[{"op":"add","path":"/spec/template/spec/tolerations/-","value":{"key":"node.cloudprovider.kubernetes.io/uninitialized","value":"true","effect":"NoSchedule"}}]'

kubectl apply -f https://raw.githubusercontent.com/kubernetes/csi-api/release-1.14/pkg/crd/manifests/csidriver.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/csi-api/release-1.14/pkg/crd/manifests/csinodeinfo.yaml
kubectl apply -f https://raw.githubusercontent.com/hetznercloud/csi-driver/master/deploy/kubernetes/hcloud-csi.yml

# Setup hetzner cloud load balancer
# See https://github.com/hetznercloud/hcloud-cloud-controller-manager#deployment
# Skipped as it did not work! For now we setup metallb
# kubectl -n kube-system create secret generic hcloud --from-literal=token=$HCLOUD_TOKEN
# kubectl apply -f https://raw.githubusercontent.com/hetznercloud/hcloud-cloud-controller-manager/master/deploy/v1.6.1.yaml
