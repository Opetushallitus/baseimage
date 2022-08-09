# Strict mode
set -eu

echo "Installing dependencies"
apk update
apk --no-cache add \
  bash \
  bzip2 \
  ca-certificates \
  jq \
  openssh \
  openssl \
  python3 \
  py-pip \
  py3-jinja2 \
  unzip \
  fontconfig \
  ttf-dejavu \
  wget \
  zip \
  util-linux \
  musl-utils \
  musl-locales \
  musl-locales-lang \
  tzdata \
  freetype

ln -s /usr/bin/python3 /usr/bin/python

echo "Kludging font libraries in place"
ln -s /usr/lib/libfontconfig.so.1 /usr/lib/libfontconfig.so && \
  ln -s /lib/libuuid.so.1 /usr/lib/libuuid.so.1 && \
  ln -s /lib/libc.musl-x86_64.so.1 /usr/lib/libc.musl-x86_64.so.1

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

echo "Creating cache directories for package managers"
mkdir /home/oph/.m2/
mkdir /home/oph/.ivy2/

echo "Installing Prometheus jmx_exporter"
JMX_EXPORTER_VERSION="0.15.0"
wget -q https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar
mv jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar jmx_prometheus_javaagent.jar
echo "a1061f29088ac2709da076a97736de575a872538  jmx_prometheus_javaagent.jar" |sha1sum -c
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