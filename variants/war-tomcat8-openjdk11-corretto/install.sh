# Strict mode
set -eu

case "$(uname -m)" in
  aarch64) ARCHITECTURE="arm64" ;;
  x86_64) ARCHITECTURE="amd64" ;;
  *) ARCHITECTURE=$(uname -m) ;;
esac
echo $ARCHITECTURE

echo "Installing dependencies"
yum update -y && yum install -y \
  bash \
  bzip2 \
  ca-certificates \
  fontconfig \
  jq \
  lftp \
  openssh-server \
  openssl \
  python3 \
  python3-pip \
  python3-jinja2 \
  unzip \
  wget \
  zip \
  tar \
  util-linux \
  fontconfig \
  dejavu-fonts-common \
  glibc-locale-source \
  glibc-langpack-en \
  glibc-langpack-fi && yum clean all && rm -rf /var/cache/yum

echo "Installing tools for downloading environment configuration during service run script"
pip3 install --upgrade pip
pip3 install \
  awscli \
  docker-py \
  j2cli \
  jinja2 \
  jinja2-cli \
  pyasn1 \
  six
rm -rf /root/.cache

localedef -i en_US -f UTF-8 en_US.UTF-8
localedef -i fi_FI -f UTF-8 fi_FI.UTF-8

echo "Creating cache directories for package managers"
mkdir -p /home/oph/.m2/
mkdir -p /home/oph/.ivy2/

echo "Installing Prometheus jmx_exporter"
JMX_EXPORTER_VERSION="0.17.0"
wget -q https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar
mv jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar jmx_prometheus_javaagent.jar
echo "f52f16e90333f2b2e05a47195328a5821b0cd971  jmx_prometheus_javaagent.jar" |sha1sum -c
mv jmx_prometheus_javaagent.jar /usr/local/bin/

echo "Installing Prometheus node_exporter"
NODE_EXPORTER_VERSION="1.3.1"
wget -q https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}.tar.gz
case "$ARCHITECTURE" in
  arm64) echo "f19f35175f87d41545fa7d4657e834e3a37c1fe69f3bf56bc031a256117764e7  node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}.tar.gz" |sha256sum -c ;;
  amd64) echo "68f3802c2dd3980667e4ba65ea2e1fb03f4a4ba026cca375f15a0390ff850949  node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}.tar.gz" |sha256sum -c ;;
  *) echo "Unknown architecture" && exit 1
esac
tar -xvzf node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}.tar.gz
rm node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}.tar.gz
mv node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}/node_exporter /usr/local/bin/
rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}

echo "Init Prometheus config file"
echo "{}" > /etc/prometheus.yaml

echo "Installing Tomcat"
TOMCAT_DL_PREFIX="https://archive.apache.org/dist/tomcat/tomcat-8/v8.5.69/bin"
TOMCAT_PACKAGE="apache-tomcat-8.5.69.tar.gz"
wget -c -q -P /tmp/ ${TOMCAT_DL_PREFIX}/${TOMCAT_PACKAGE}
echo "cc9616eb29bf491839ce5c8a1c3e37cb710f6ec99aad5aefb7944b5184b13398  /tmp/${TOMCAT_PACKAGE}" |sha256sum -c
mkdir -p /opt/tomcat
tar xf /tmp/${TOMCAT_PACKAGE} -C /opt/tomcat --strip-components=1
rm -rf /opt/tomcat/webapps/*
chown -R oph:oph /opt/tomcat

echo "Copying Tomcat configuration"
mv /tmp/tomcat/conf/server.xml /opt/tomcat/conf/
mv /tmp/tomcat/lib/*.jar /opt/tomcat/lib/

echo "Clearing temp directory"
ls -la /tmp/
rm -rf /tmp/*.tar.gz
rm -rf /tmp/hsperfdata_root
rm -rf /tmp/tomcat

echo "Make run script executable"
chmod +x /usr/local/bin/run
