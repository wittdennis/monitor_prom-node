#!/usr/bin/sh

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

SCRIPT=$(readlink -f "$0")
SCRIPT_PATH=$(dirname "$SCRIPT")
NODE_EXPORTER_VERSION="1.3.1"
NODE_EXPORTER_USER="node_exporter"
BIN_DIRECTORY="/usr/local/bin"
BIN="node_exporter"
CONF_DIRECTORY="/etc/node-exporter"
ARCH="linux-amd64"

echo "Removing service"
systemctl stop node_exporter
systemctl disable node_exporter
rm /etc/systemd/system/node_exporter.service
systemctl daemon-reload

echo "Removing config directory"
rm -rf ${CONF_DIRECTORY}/

echo "Removing binaries"
rm ${BIN_DIRECTORY}/${BIN}

echo "Removing user '${NODE_EXPORTER_USER}'"
userdel -f -r ${NODE_EXPORTER_USER} > /dev/null 2>&1 