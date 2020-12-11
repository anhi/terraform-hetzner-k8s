#!/bin/bash
#
# For details see https://community.hetzner.com/tutorials/install-kubernetes-cluster#step-3---install-kubernetes
#
set -eu

# Update System
apt-get -qq update
apt-get -qq dist-upgrade -y

# Setup NFS access (required for nfs-server-provisioner w/ StorageClass nfs)
apt-get -qq install -y nfs-common

# Setup hetzner cloud controller manager
mkdir -p /etc/systemd/system/kubelet.service.d
cat <<EOF > /etc/systemd/system/kubelet.service.d/20-hetzner-cloud.conf
[Service]
Environment="KUBELET_EXTRA_ARGS=--cloud-provider=external"
EOF

# Setup Docker
mkdir -p /etc/systemd/system/docker.service.d
cat <<EOF > /etc/systemd/system/docker.service.d/00-cgroup-systemd.conf
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock --exec-opt native.cgroupdriver=systemd
EOF

systemctl daemon-reload

# Install services
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF > /etc/apt/sources.list.d/docker-and-kubernetes.list
deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable
deb http://packages.cloud.google.com/apt/ kubernetes-xenial main
EOF
apt-get -qq update
apt-get -qq install -y docker-ce kubeadm=1.19.0-00 kubectl=1.19.0-00 kubelet=1.19.0-00

# Allow traffic between nodes and pods
cat <<EOF >>/etc/sysctl.conf

# Allow IP forwarding for kubernetes
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.ipv6.conf.default.forwarding = 1
EOF

sysctl -p
