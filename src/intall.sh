#!/usr/bin/sh

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

while getopts ":c:p:" opt; do
  case $opt in
    c) GENERATE_CERT="$OPTARG"
    ;;
    p) PASSWORD="$OPTARG"
    ;;
    \?) echo "Invalid option -$OPTARG" >&2
    exit 1
    ;;
  esac

  case $OPTARG in
    -*) echo "Option $opt needs a valid argument"
    exit 1
    ;;
  esac
done

SCRIPT=$(readlink -f "$0")
SCRIPT_PATH=$(dirname "$SCRIPT")
NODE_EXPORTER_VERSION="1.3.1"
NODE_EXPORTER_USER="node_exporter"
BIN_DIRECTORY="/usr/local/bin"
BIN="node_exporter"
CONF_DIRECTORY="/etc/node-exporter"
ARCH="linux-amd64"
PORT="9100"

echo "Creating user '${NODE_EXPORTER_USER}' if not present"
id -u ${NODE_EXPORTER_USER} > /dev/null 2>&1 || useradd -r -s /usr/bin/bash -U -m ${NODE_EXPORTER_USER} 

# install bin
echo "Downloading Node Exporter v${NODE_EXPORTER_VERSION}"
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.${ARCH}.tar.gz
echo "Copying '${BIN}' to '${BIN_DIRECTORY}'"
tar -xf node_exporter-${NODE_EXPORTER_VERSION}.${ARCH}.tar.gz
cp node_exporter-${NODE_EXPORTER_VERSION}.${ARCH}/node_exporter ${BIN_DIRECTORY}/${BIN}
chown ${NODE_EXPORTER_USER}:${NODE_EXPORTER_USER} ${BIN_DIRECTORY}/${BIN}
rm -rf node_exporter-${NODE_EXPORTER_VERSION}.${ARCH}*

# config
mkdir ${CONF_DIRECTORY}

if [ -z "${GENERATE_CERT}" ] || [ "${GENERATE_CERT}" != "false" ]
then
  echo "Generating self-signed certificate"
  # self-signed localhost cert
  openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -keyout node_exporter.key -out node_exporter.crt -subj "/CN=localhost" -addext "subjectAltName = DNS:localhost"
  mv node_exporter.* ${CONF_DIRECTORY}/
fi

cp ${SCRIPT_PATH}/config.yml ${CONF_DIRECTORY}/
cp ${SCRIPT_PATH}/node_exporter.service /etc/systemd/system/

RAND_PW=0
if [ -z "${PASSWORD}" ]
then
  echo "Generating password for basic auth"
  PASSWORD=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c32;)
  RAND_PW=1
fi


# change values of config file and systemd service
PASSWD=$(htpasswd -nbBC 10 "" ${PASSWORD} | tr -d ':\n')
sed -i "s@\${PW}@${PASSWD}@g" "${CONF_DIRECTORY}/config.yml"
sed -i "s@\${NODE_EXPORTER_USER}@${NODE_EXPORTER_USER}@g" "/etc/systemd/system/node_exporter.service"
sed -i "s@\${BIN_DIRECTORY}@${BIN_DIRECTORY}@g" "/etc/systemd/system/node_exporter.service"
sed -i "s@\${BIN}@${BIN}@g" "/etc/systemd/system/node_exporter.service"
sed -i "s@\${CONF_DIRECTORY}@${CONF_DIRECTORY}@g" "/etc/systemd/system/node_exporter.service"
sed -i "s@\${PORT}@${PORT}@g" "/etc/systemd/system/node_exporter.service"

chown -R ${NODE_EXPORTER_USER}:${NODE_EXPORTER_USER} ${CONF_DIRECTORY}

systemctl daemon-reload
systemctl enable node_exporter
systemctl restart node_exporter

echo ""
echo "Started node_exporter on: https://localhost:${PORT}"
echo "Use the following user and password to connect"
if [ ${RAND_PW} -eq 1 ]
then
  echo "prometheus: ${PASSWORD}"
else
  echo "prometheus: ***********"
fi

echo ""
echo "Done!"