#!/bin/bash

# there where some changes and fixes needed for this to work:
# Assumes Ubuntu 18.04 & go 1.13 installed at GOPATH="~/go"
cd $GOPATH/src/github.com
git clone -b midokura-poc git@github.com:kubeedge/kubeedge.git
cd kubeedge
make
cp keadm/keadm /usr/local/bin

# this will "succeed" but cloudcore will not start due to missing config
keadm init --kubeedge-version=1.2.0 --kubernetes-version=1.17.1-00 --docker-version=19.03.6~3-0~ubuntu-bionic --pod-network-cidr 10.36.0.0/16 --kube-config=/root/.kube/config
wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
sed -i 's|10\.244\.0\.0|10\.36\.0\.0|' kube-flannel.yml
kubectl apply -f kube-flannel.yml
rm kube-flannel.yml
kubectl get pods -A

cp cloud/cloudcore /usr/local/bin/

cloudcore --minconfig > /etc/kubeedge/config/cloudcore.yaml
sed -i "s|  master: \"\"|  master: \"http://localhost:8080\"|" /etc/kubeedge/config/cloudcore.yaml

# create KubeEdge CRDs
kubectl apply -f build/crds/devices/devices_v1alpha1_devicemodel.yaml
kubectl apply -f build/crds/devices/devices_v1alpha1_device.yaml
kubectl apply -f build/crds/reliablesyncs/cluster_objectsync_v1alpha1.yaml
kubectl apply -f build/crds/reliablesyncs/objectsync_v1alpha1.yaml

# run cloud core, screen session: screen -L -Logfile /var/log/cloudcore.log cloudcore
cloudcore &

# check (once edgecore is deployed)
kubectl get nodes -l node-role.kubernetes.io/edge=

