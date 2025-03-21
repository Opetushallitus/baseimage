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
  py3-pip \
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

echo "Installing tools for downloading environment configuration during service run script"

pip install \
  awscli \
  docker-py \
  j2cli \
  jinja2 \
  jinja2-cli \
  pyasn1 \
  six \
  --break-system-packages \
  --no-cache-dir


echo "Creating cache directories for package managers"
mkdir -p /home/oph/.m2/
mkdir -p /home/oph/.ivy2/

mkdir -p /etc/oph

echo "Installing Bouncy Castle bcprov security provider"
BCPROV_DL_PREFIX="https://downloads.bouncycastle.org/java"
BCPROV_PACKAGE="bcprov-jdk15to18-176.jar"
wget -c -q -P ${JAVA_HOME}/lib/ext/ ${BCPROV_DL_PREFIX}/${BCPROV_PACKAGE}
echo "1c43883ac1c69ed43a13d48d130420ff3562422d0a7d2910cfa77a3e3ee6400a  ${JAVA_HOME}/lib/ext/${BCPROV_PACKAGE}" |sha256sum -c

echo "Updating java.security"
JAVA_SECURITY_FILE=$JAVA_HOME/lib/security/java.security
TMP_SECURITY_FILE=/tmp/java.security.new
BC_SECURITY_PROVIDER_LINE="security.provider.10=org.bouncycastle.jce.provider.BouncyCastleProvider"
awk -v line_to_insert="$BC_SECURITY_PROVIDER_LINE" '/^security.provider./ { if (inserted!=1) {print line_to_insert; inserted=1}  } { print $0 }' $JAVA_SECURITY_FILE > $TMP_SECURITY_FILE
sed -i 's/#*networkaddress.cache.ttl=.*/networkaddress.cache.ttl=30/g' $TMP_SECURITY_FILE
mv $TMP_SECURITY_FILE $JAVA_SECURITY_FILE

echo "Installing Prometheus jmx_exporter"
JMX_EXPORTER_VERSION="0.20.0"
wget -q https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_EXPORTER_VERSION}/jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar
mv jmx_prometheus_javaagent-${JMX_EXPORTER_VERSION}.jar jmx_prometheus_javaagent.jar
echo "7b8a98e3482cee8889698ef391b85c47a3c4ce5b  jmx_prometheus_javaagent.jar" |sha1sum -c
mv jmx_prometheus_javaagent.jar /usr/local/bin/

echo "Installing Prometheus node_exporter"
NODE_EXPORTER_VERSION="1.8.1"
wget -q https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}.tar.gz
case "$ARCHITECTURE" in
  arm64) echo "3b5c4765e429d73d0ec83fcd14af39087025e1f7073422fa24be8f4fa3d3bb96  node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}.tar.gz" |sha256sum -c ;;
  amd64) echo "fbadb376afa7c883f87f70795700a8a200f7fd45412532cc1938a24d41078011  node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}.tar.gz" |sha256sum -c ;;
  *) echo "Unknown architecture" && exit 1
esac
tar -xvzf node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}.tar.gz
rm node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}.tar.gz
mv node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}/node_exporter /usr/local/bin/
rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCHITECTURE}

echo "Installing Otel agent"
OTEL_VERSION="1.32.2"
wget -q https://github.com/aws-observability/aws-otel-java-instrumentation/releases/download/v${OTEL_VERSION}/aws-opentelemetry-agent.jar
mv aws-opentelemetry-agent.jar /usr/local/bin/

echo "Init Prometheus config file"
echo "{}" > /etc/prometheus.yaml

echo "Make run script executable"
chmod +x /usr/local/bin/run
