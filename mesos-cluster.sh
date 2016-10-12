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
HOSTS=(172.16.155.140 172.16.157.167 172.16.157.170 172.16.157.171 172.16.157.198 172.16.157.199)
BOOTSTRAP=172.16.158.11
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
  echo "PrepareOS - Skip yum update for $1"
  ssh -o StrictHostKeyChecking=no $1 "yum update -y"
  ssh -o StrictHostKeyChecking=no $1 "yum upgrade -y"
  #ssh -o StrictHostKeyChecking=no $1 "systemctl stop firewalld"
  #ssh -o StrictHostKeyChecking=no $1 "systemctl disable firewalld"
}

function installDocker {
  echo "InstallDocker for $1"
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

function uninstallDCOS {
  uninstallDCOSBootstrap
  for node in ${HOSTS[@]}; do
    uninstallDCOSNode ${node}
  done
  rm -rf backup
}

function uninstallDCOSBootstrap {
  echo "Uninstall previous version of DCOS for $1"
  # Delete all containers
  ssh -o StrictHostKeyChecking=no $BOOTSTRAP "docker rm \$(docker ps -a -q)"
  # Delete all images
  ssh -o StrictHostKeyChecking=no $BOOTSTRAP "docker rmi \$(docker images -q)"
  # Uninstall
  ssh -o StrictHostKeyChecking=no $BOOTSTRAP "cd /opt/dcos-install && bash dcos_generate_config.sh --uninstall --offline"
  ssh -o StrictHostKeyChecking=no $BOOTSTRAP "rm -rf /opt/dcos-install"
  ssh -o StrictHostKeyChecking=no $BOOTSTRAP "rm -rf /opt/dcos_install_tmp"
  ssh -o StrictHostKeyChecking=no $BOOTSTRAP "rm -rf /opt/dcos-prereqs.installed"
}

function uninstallDCOSNode {
  echo "Uninstall previous version of DCOS for $1"
  ssh -o StrictHostKeyChecking=no $1 "/opt/mesosphere/bin/pkgpanda uninstall"
  ssh -o StrictHostKeyChecking=no $1 "rm -rf /opt/dcos-install"
  ssh -o StrictHostKeyChecking=no $1 "rm -rf /opt/dcos_install_tmp"
  ssh -o StrictHostKeyChecking=no $1 "rm -rf /opt/dcos-prereqs.installed"
  ssh -o StrictHostKeyChecking=no $1 "rm -rf /opt/mesosphere"
  ssh -o StrictHostKeyChecking=no $1 "rm -rf /var/lib/dcos"
  ssh -o StrictHostKeyChecking=no $1 "rm -rf /var/lib/mesosphere"
  ssh -o StrictHostKeyChecking=no $1 "rm -rf /var/lib/mesos"
  ssh -o StrictHostKeyChecking=no $1 "rm -rf /var/lib/zookeeper"
  ssh -o StrictHostKeyChecking=no $1 "rm -rf /var/log/mesos"
  ssh -o StrictHostKeyChecking=no $1 "rm -rf /etc/mesosphere"
  ssh -o StrictHostKeyChecking=no $1 "rm -rf /etc/profile.d/dcos.sh"
  ssh -o StrictHostKeyChecking=no $1 "rm -rf /etc/systemd/journald.conf.d/dcos.conf"
  ssh -o StrictHostKeyChecking=no $1 "rm -rf /etc/systemd/system/dcos-cfn-signal.service"
  ssh -o StrictHostKeyChecking=no $1 "rm -rf /etc/systemd/system/dcos-download.service"
  ssh -o StrictHostKeyChecking=no $1 "rm -rf /etc/systemd/system/dcos-link-env.service"
  ssh -o StrictHostKeyChecking=no $1 "rm -rf /etc/systemd/system/dcos-setup.service"
  ssh -o StrictHostKeyChecking=no $1 "rm -rf /etc/systemd/system/dcos.target.wants"
  ssh -o StrictHostKeyChecking=no $1 "rm -rf /etc/systemd/system/dcos.target.wants.old"
  ssh -o StrictHostKeyChecking=no $1 "rm -rf /etc/systemd/system/multi-user.target.wants/dcos-setup.service"
  ssh -o StrictHostKeyChecking=no $1 "rm -rf /etc/systemd/system/multi-user.target.wants/dcos.target"
  ssh -o StrictHostKeyChecking=no $1 "rm -rf /run/dcos"
}

function prepareDCOS {
  echo "Prepare DCOS for $1"
  ssh -o StrictHostKeyChecking=no $1 "rm -rf /opt/dcos-install"
  ssh -o StrictHostKeyChecking=no $1 "mkdir -p /opt/dcos-install/genconf"
  ssh -o StrictHostKeyChecking=no $1 "mkdir -p /opt/dcos-install/tmp"

  cat dcos/genconf/config.yaml | ssh -o StrictHostKeyChecking=no $1 "cat > /opt/dcos-install/genconf/config.yaml"
  cat dcos/genconf/ip-detect | ssh -o StrictHostKeyChecking=no $1 "cat > /opt/dcos-install/genconf/ip-detect"
  ssh -o StrictHostKeyChecking=no $1 "cp ~/.ssh/id_rsa /opt/dcos-install/genconf/ssh_key && chmod 600 /opt/dcos-install/genconf/ssh_key"

  ssh -o StrictHostKeyChecking=no $1 "cd /opt/dcos-install && curl -OL https://downloads.dcos.io/dcos/stable/dcos_generate_config.sh"
}

function installDCOS {
  echo "Install DCOS for $1"
  ssh -o StrictHostKeyChecking=no $1 "cd /opt/dcos-install && bash dcos_generate_config.sh --genconf"
  ssh -o StrictHostKeyChecking=no $1 "cd /opt/dcos-install && bash dcos_generate_config.sh --install-prereqs"
  ssh -o StrictHostKeyChecking=no $1 "cd /opt/dcos-install && bash dcos_generate_config.sh --preflight"
  ssh -o StrictHostKeyChecking=no $1 "cd /opt/dcos-install && bash dcos_generate_config.sh --deploy"
  ssh -o StrictHostKeyChecking=no $1 "cd /opt/dcos-install && bash dcos_generate_config.sh --postflight"
}

function backupDCOS {
  echo "Backing up DCOS install files to $1"
  ssh -o StrictHostKeyChecking=no $1 "cd /opt/dcos-install/genconf/serve && tar cf dcos-install.tar *"
  mkdir backup
  scp $1:/opt/dcos-install/genconf/serve/dcos-install.tar backup/dcos-install.tar
  ssh -o StrictHostKeyChecking=no $1 "cd /opt/dcos-install/genconf/serve && rm dcos-install.tar"
}

uninstallDCOS

prepareOs     $BOOTSTRAP
for node in ${HOSTS[@]}; do
  prepareOs ${node}
done

installDocker $BOOTSTRAP
prepareDCOS   $BOOTSTRAP
installDCOS   $BOOTSTRAP
backupDCOS    $BOOTSTRAP