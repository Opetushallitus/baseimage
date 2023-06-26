# Strict mode
set -eu

case "$(uname -m)" in
  aarch64) ARCHITECTURE="arm64" ;;
  x86_64) ARCHITECTURE="amd64" ;;
  *) ARCHITECTURE=$(uname -m) ;;
esac
echo $ARCHITECTURE

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

ln -sf /usr/bin/python3 /usr/bin/python

echo "Kludging font libraries in place"
ln -s /usr/lib/libfontconfig.so.1 /usr/lib/libfontconfig.so && \
  ln -s /lib/libuuid.so.1 /usr/lib/libuuid.so.1 && \
  ln -s /lib/libc.musl-$(uname -m).so.1 /usr/lib/libc.musl-$(uname -m).so.1

echo "Installing tools for downloading environment configuration during service run script"
python -m ensurepip --upgrade
python -m pip install \
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

echo "Updating java.security"
JAVA_SECURITY_FILE=$JAVA_HOME/lib/security/java.security
sed -i 's/#*networkaddress.cache.ttl=.*/networkaddress.cache.ttl=30/g' $JAVA_SECURITY_FILE

echo "Installing Prometheus jmx_exporter"
JMX_EXPORTER_VERSION="0.18.0"
wget -q https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar
mv jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar jmx_prometheus_javaagent.jar
echo "889ad8ac7b516a751b50a2a7ce82f611d34f8376  jmx_prometheus_javaagent.jar" |sha1sum -c
mv jmx_prometheus_javaagent.jar /usr/local/bin/

echo "Installing Prometheus node_exporter"
NODE_EXPORTER_VERSION="1.6.0"
wget -q https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}.tar.gz
case "$ARCHITECTURE" in
  arm64) echo "eb2f24626eca824c077cc7675d762bd520161c5c1a3f33c57b4b8aa0d452d613  node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}.tar.gz" |sha256sum -c ;;
  amd64) echo "0b3573f8a7cb5b5f587df68eb28c3eb7c463f57d4b93e62c7586cb6dc481e515  node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}.tar.gz" |sha256sum -c ;;
  *) echo "Unknown architecture" && exit 1
esac
tar -xvzf node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}.tar.gz
rm node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}.tar.gz
mv node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}/node_exporter /usr/local/bin/
rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}

echo "Installing Otel agent"
OTEL_VERSION="1.27.0"
wget -q https://github.com/aws-observability/aws-otel-java-instrumentation/releases/download/v${OTEL_VERSION}/aws-opentelemetry-agent.jar
mv aws-opentelemetry-agent.jar /usr/local/bin/

echo "Init Prometheus config file"
echo "{}" > /etc/prometheus.yaml

echo "Installing Tomcat"
TOMCAT_DL_PREFIX="https://archive.apache.org/dist/tomcat/tomcat-8/v8.5.87/bin"
TOMCAT_PACKAGE="apache-tomcat-8.5.87.tar.gz"
wget -c -q -P /tmp/ ${TOMCAT_DL_PREFIX}/${TOMCAT_PACKAGE}
echo "86acc508b29ca1928a6597379f1c3dc79c767922e863c9145e2477768b4f2a75  /tmp/${TOMCAT_PACKAGE}" |sha256sum -c
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