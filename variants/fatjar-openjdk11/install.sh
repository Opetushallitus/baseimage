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
  fontconfig \
  jq \
  lftp \
  openssh \
  openssl \
  python3 \
  py3-jinja2 \
  ttf-dejavu \
  unzip \
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
mkdir -p /home/oph/.m2/
mkdir -p /home/oph/.ivy2/

mkdir -p /etc/oph

echo "Updating java.security"
JAVA_SECURITY_FILE=$JAVA_HOME/conf/security/java.security
sed -i 's/#*networkaddress.cache.ttl=.*/networkaddress.cache.ttl=30/g' $JAVA_SECURITY_FILE

echo "Installing Prometheus jmx_exporter"
JMX_EXPORTER_VERSION="0.20.0"
wget -q https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar
mv jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar jmx_prometheus_javaagent.jar
echo "7b8a98e3482cee8889698ef391b85c47a3c4ce5b  jmx_prometheus_javaagent.jar" |sha1sum -c
mv jmx_prometheus_javaagent.jar /usr/local/bin/

echo "Installing Prometheus node_exporter"
NODE_EXPORTER_VERSION="1.7.0"
wget -q https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}.tar.gz
case "$ARCHITECTURE" in
  arm64) echo "e386c7b53bc130eaf5e74da28efc6b444857b77df8070537be52678aefd34d96  node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}.tar.gz" |sha256sum -c ;;
  amd64) echo "a550cd5c05f760b7934a2d0afad66d2e92e681482f5f57a917465b1fba3b02a6  node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}.tar.gz" |sha256sum -c ;;
  *) echo "Unknown architecture" && exit 1
esac
tar -xvzf node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}.tar.gz
rm node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}.tar.gz
mv node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}/node_exporter /usr/local/bin/
rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}

echo "Installing Otel agent"
OTEL_VERSION="1.32.0"
wget -q https://github.com/aws-observability/aws-otel-java-instrumentation/releases/download/v${OTEL_VERSION}/aws-opentelemetry-agent.jar
mv aws-opentelemetry-agent.jar /usr/local/bin/

echo "Init Prometheus config file"
echo "{}" > /etc/prometheus.yaml

echo "Make run script executable"
chmod +x /usr/local/bin/run
