# Strict mode
set -eu

echo "Test that required software is installed"
yum --version
aws --version
java -version
j2 --version
cat /etc/os-release

echo "Test that baseimage has files expected by the application during run script"
ls -la /usr/local/bin/jmx_prometheus_javaagent.jar
ls -la /usr/local/bin/node_exporter
ls -la /usr/local/bin/run
ls -la /etc/oph/
ls -la ${JAVA_HOME}/jre/lib/security/cacerts

echo "Largest directories:"
du -d 3 -m /|sort -nr|head -n 20
