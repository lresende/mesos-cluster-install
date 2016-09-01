#!/bin/bash
#
# Copyright 2016 Luciano Resende
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ROOT=`dirname $0`
ROOT=`cd $ROOT; pwd`

#if [ -z "$1" ]
#then
#  echo "Usage:"
#  echo "  mesos-cluster.sh [option]"
#  echo " "
#  exit 1
#fi

INSTALL_FOLDER=/opt

LOCALHOST="$(/bin/hostname -f)"
HOSTS=(172.16.157.167 172.16.159.216 172.16.159.219 172.16.159.220 172.16.159.221 172.16.159.222)
BOOTSTRAP=172.16.159.223
MASTER=${HOSTS[1]}
MASTER_PUBLIC=9.30.167.3
NODES=${HOSTS[@]:2}

NODES=("${HOSTS[@]:2}") ##Workaround to get node size
NODE_SIZE=${#NODES[@]}

echo ">>> Cluster Configuration "
echo "Bootstrap .........: $BOOTSTRAP"
echo "Master ............: $MASTER"
echo "Master Public......: $MASTER_PUBLIC"
echo "Nodes..............: ${NODES[@]}"
echo ">>> "

function prepareOs {
  ssh -o StrictHostKeyChecking=no $1 "yum update -y"
  ssh -o StrictHostKeyChecking=no $1 "yum upgrade -y"
  #ssh -o StrictHostKeyChecking=no $1 "systemctl stop firewalld"
  #ssh -o StrictHostKeyChecking=no $1 "systemctl disable firewalld"
}

function installDocker {
  cat etc/yum.repos.d/docker.repo | ssh -o StrictHostKeyChecking=no $1 "cat > /etc/yum.repos.d/docker.repo"

  #ssh -o StrictHostKeyChecking=no $1 "curl -fsSL https://get.docker.com/ | sh"
  ssh -o StrictHostKeyChecking=no $1 "yum install -y docker-engine"

  #ssh -o StrictHostKeyChecking=no ${i} "mkdir -p /etc/systemd/system/docker.service.d"
  #cat etc/systemd/system/docker.service.d/override.conf | ssh -o StrictHostKeyChecking=no $1 "cat > /etc/systemd/system/docker.service.d/override.conf"
  cat usr/lib/systemd/system/docker.service | ssh -o StrictHostKeyChecking=no $1 "cat > /usr/lib/systemd/system/docker.service"
  cat usr/lib/systemd/system/docker.socket | ssh -o StrictHostKeyChecking=no $1 "cat > /usr/lib/systemd/system/docker.socket"

  ssh -o StrictHostKeyChecking=no $1 "systemctl daemon-reload"
  ssh -o StrictHostKeyChecking=no $1 "systemctl start docker"
  ssh -o StrictHostKeyChecking=no $1 "systemctl enable docker"
}

function prepareDCOS {
  ssh -o StrictHostKeyChecking=no $1 "rm -rf /opt/dcos-install"
  ssh -o StrictHostKeyChecking=no $1 "mkdir -p /opt/dcos-install/genconf"
  ssh -o StrictHostKeyChecking=no $1 "mkdir -p /opt/dcos-install/tmp"

  cat dcos/genconf/config.yaml | ssh -o StrictHostKeyChecking=no $1 "cat > /opt/dcos-install/genconf/config.yaml"
  cat dcos/genconf/ip-detect | ssh -o StrictHostKeyChecking=no $1 "cat > /opt/dcos-install/genconf/ip-detect"
  ssh -o StrictHostKeyChecking=no $1 "cp ~/.ssh/id_rsa /opt/dcos-install/genconf/ssh_key && chmod 600 /opt/dcos-install/genconf/ssh_key"

  ssh -o StrictHostKeyChecking=no $1 "cd /opt/dcos-install && curl -OL https://downloads.dcos.io/dcos/EarlyAccess/dcos_generate_config.sh"
}

function installDCOS {
  ssh -o StrictHostKeyChecking=no $1 "cd /opt/dcos-install && bash dcos_generate_config.sh --genconf"
  ssh -o StrictHostKeyChecking=no $1 "cd /opt/dcos-install && bash dcos_generate_config.sh --install-prereqs"
  ssh -o StrictHostKeyChecking=no $1 "cd /opt/dcos-install && bash dcos_generate_config.sh --preflight"
  ssh -o StrictHostKeyChecking=no $1 "cd /opt/dcos-install && bash dcos_generate_config.sh --deploy"
  ssh -o StrictHostKeyChecking=no $1 "cd /opt/dcos-install && bash dcos_generate_config.sh --postflight"
}

prepareOs     $BOOTSTRAP
for node in ${HOSTS[@]}; do
  prepareOs ${node}
done

installDocker $BOOTSTRAP
prepareDCOS   $BOOTSTRAP
installDCOS   $BOOTSTRAP
