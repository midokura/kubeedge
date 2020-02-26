#!/bin/bash

mkdir -p /etc/kubeedge/{ca,certs,config} /var/lib/kubeedge

# now, copy certificates generated on cloudcore side to thishost:
#  scp /etc/kubeedge/ca/rootCA.crt root@thishost:/etc/kubeedge/ca/
#  scp /etc/kubeedge/certs/edge.{crt,key} root@thishost:/etc/kubeedge/certs/

wget https://github.com/kubeedge/kubeedge/releases/download/v1.2.0/kubeedge-v1.2.0-linux-arm.tar.gz
tar -xvf kubeedge-v1.2.0-linux-arm.tar.gz
cp kubeedge-v1.2.0-linux-arm/edge/edgecore kubeedge-v1.2.0-linux-arm/cloud/csidriver/csidriver kubeedge-v1.2.0-linux-arm/cloud/admission/admission /usr/local/bin/
rm -rf kubeedge-v1.2.0-linux-arm

cat > /etc/kubeedge/config/edgecore.yaml << EOF
apiVersion: edgecore.config.kubeedge.io/v1alpha1
database:
  dataSource: /var/lib/kubeedge/edgecore.db
kind: EdgeCore
modules:
  edged:
    cgroupDriver: systemd
    clusterDNS: ""
    clusterDomain: ""
    devicePluginEnabled: false
    dockerAddress: unix:///var/run/docker.sock
    gpuPluginEnabled: false
#    hostnameOverride: raspberrypi4b
    interfaceName: eth0
    nodeIP: $(hostname -I | awk '{ print $1 }')
    podSandboxImage: kubeedge/pause-arm64:3.1
    remoteImageEndpoint: unix:///var/run/dockershim.sock
    remoteRuntimeEndpoint: unix:///var/run/dockershim.sock
    runtimeType: docker
  edgehub:
    heartbeat: 15
    tlsCaFile: /etc/kubeedge/ca/rootCA.crt
    tlsCertFile: /etc/kubeedge/certs/edge.crt
    tlsPrivateKeyFile: /etc/kubeedge/certs/edge.key
    websocket:
      enable: true
      handshakeTimeout: 30
      readDeadline: 15
      server: 10.0.100.53:10000
      writeDeadline: 15
  eventbus:
    mqttMode: 2
    mqttQOS: 0
    mqttRetain: false
    mqttServerExternal: tcp://127.0.0.1:1883
    mqttServerInternal: tcp://127.0.0.1:1884
EOF

apt install mosquitto

# should run this in local container
screen -L -Logfile /var/log/edgecore.log edgecore

