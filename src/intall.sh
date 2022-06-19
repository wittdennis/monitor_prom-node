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
CONF_DIRECTORY="/etc/node-exporter"
ARCH="linux-amd64"
RAND_PW=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c32;)

echo "Creating user '${NODE_EXPORTER_USER}' if not present"
id -u ${NODE_EXPORTER_USER} 2>&1 /dev/null || useradd --system --shell /usr/bin/bash --user-group --disabled-password --home /home/${NODE_EXPORTER_USER} ${NODE_EXPORTER_USER} 

# install bin
echo "Downloading Node Exporter v${NODE_EXPORTER_VERSION}"
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.${ARCH}.tar.gz
tar -xf node_exporter-${NODE_EXPORTER_VERSION}.${ARCH}.tar.gz
cp node_exporter-${NODE_EXPORTER_VERSION}.${ARCH}/node_exporter ${BIN_DIRECTORY}/
chown ${NODE_EXPORTER_USER}:${NODE_EXPORTER_USER} ${BIN_DIRECTORY}/node_exporter
rm -rf node_exporter-${NODE_EXPORTER_VERSION}.${ARCH}*

# config
mkdir ${CONF_DIRECTORY}
# self-signed localhost cert
openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -keyout node_exporter.key -out node_exporter.crt -subj "/C=ZA/ST=CT/L=SA/O=VPN/CN=localhost" -addext "subjectAltName = DNS:localhost"
mv node_exporter.* ${CONF_DIRECTORY}/
cp ${SCRIPT_PATH}/config.yml ${CONF_DIRECTORY}/
cp ${SCRIPT_PATH}/node_exporter.service /etc/systemd/system/

# change values of config file and systemd service
echo "Generating password for basic auth"
PASSWD=$(htpasswd -nbBC 17 "" ${RAND_PW} | tr -d ':\n')

chown -R ${NODE_EXPORTER_USER}:${NODE_EXPORTER_USER} ${CONF_DIRECTORY}

systemctl daemon-reload
systemctl enable node_exporter
systemctl restart node_exporter

echo ""
echo "Use the following user and password to connect"
echo "prometheus: ${RAND_PW}"

echo ""
echo "Done!"