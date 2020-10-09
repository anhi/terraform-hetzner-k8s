#!/bin/sh
set -eu

# TODO remove this in environments with only helm3 installed as helm
HELM=helm3

# Setup MetalLB
# See https://community.hetzner.com/tutorials/install-kubernetes-cluster#step-35---setup-loadbalancing-optional
$HELM repo add bitnami https://charts.bitnami.com/bitnami
$HELM repo update

kubectl create namespace metallb
$HELM install metallb bitnami/metallb --namespace metallb

cat <<EOF | kubectl apply -f-
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: default
  name: metallb
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - $HCLOUD_FLOATING_IP/32
EOF

# Setup IP Failover
# See https://community.hetzner.com/tutorials/install-kubernetes-cluster#step-36---setup-floating-ip-failover-optional
$HELM repo add cbeneke https://cbeneke.github.com/helm-charts
$HELM repo update

kubectl create namespace fip-controller
$HELM install hcloud-fip-controller cbeneke/hcloud-fip-controller --namespace fip-controller

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: hcloud-fip-controller-config
  namespace: fip-controller
data:
  config.json: |
    {
      "hcloud_floating_ips": [
        "$HCLOUD_FLOATING_IP"
      ],
      "node_address_type": "external"
    }
---
apiVersion: v1
kind: Secret
metadata:
  name: hcloud-fip-controller-env
  namespace: fip-controller
stringData:
  HCLOUD_API_TOKEN: $HCLOUD_TOKEN
EOF
