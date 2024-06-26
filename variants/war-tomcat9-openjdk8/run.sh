#!/bin/bash
#
set -e

BASEPATH="/home/oph"
CONFIGPATH="/home/oph/oph-environment"
VARS="${CONFIGPATH}/opintopolku.yml"
LOGPATH="${CONFIGPATH}/log"
export CATALINA_BASE="/home/oph/tomcat"
export CATALINA_HOME="/opt/tomcat"
export CATALINA_TMPDIR="/tmp/catalina_temp"

echo "Copying templates to home directory"
cp -vr /etc/oph/. ${BASEPATH}

echo "Downloading environment-specific properties"
env_config_path=${ENV_CONFIG_S3_PATH:-/services/}
env_config_version=${ENV_CONFIG_VERSION:-latest}
aws s3 cp s3://${ENV_BUCKET}${env_config_path}${env_config_version}/ ${CONFIGPATH}/ --recursive --exclude "templates/*"

# append SSM parameters to $VARS
ssm_vars=$(env | grep ssm_ || test ${?} = 1)
for ssm_var in ${ssm_vars}; do
  var_name=$(echo "${ssm_var}" | sed "s/ssm_//g" | cut -d "=" -f 1)
  var_value=$(echo "${ssm_var}" | cut -d "=" -f 2-)
  echo "${var_name}: \"${var_value}\"" >> "${VARS}"
done

mkdir -p ${BASEPATH}/oph-configuration
cp -vr ${CONFIGPATH}/* ${BASEPATH}/oph-configuration/

echo "Overwriting with AWS-specific configs..."
for AWS_TEMPLATE in `find ${BASEPATH}/ -name "*.template.aws"`
do
  ORIGINAL_TEMPLATE=`echo ${AWS_TEMPLATE} | sed "s/\.aws//g"`
  cp -v ${AWS_TEMPLATE} ${ORIGINAL_TEMPLATE}
done

echo "Processing configuration files..."
for tpl in `find ${BASEPATH}/ -name "*.template"`
do
  target=`echo ${tpl} | sed "s/\.template//g"`
  echo "Prosessing ${tpl} -> ${target}"
  j2 ${tpl} ${VARS} > ${target}
  chmod 0755 ${target}
done

echo "Copying keystore file to home directory"
cp ${JAVA_HOME}/lib/security/cacerts /home/oph/

export LC_CTYPE=fi_FI.UTF-8
export JAVA_TOOL_OPTIONS='-Dfile.encoding=UTF-8'
export JMX_PORT=1133

for directory in bin conf lib temp webapps work; do
  mkdir -p ${CATALINA_BASE}/${directory}
done
ln -s /home/oph/logs/ ${CATALINA_BASE}/logs
mkdir -p ${CATALINA_TMPDIR}

cp ${CONFIGPATH}/log/logback-access.xml ${CATALINA_BASE}/conf/

echo "Copying war file to CATALINA_BASE/webapps"
ln -s /opt/tomcat/webapps/* ${CATALINA_BASE}/webapps/
cp -vr /opt/tomcat/conf/* ${CATALINA_BASE}/conf/
cp -v ${CATALINA_HOME}/bin/tomcat-juli.jar ${CATALINA_BASE}/bin/


echo "Starting Prometheus node_exporter..."
nohup /usr/local/bin/node_exporter > /home/oph/node_exporter.log  2>&1 &

if [ ${DEBUG_ENABLED} == "true" ]; then
  echo "JDWP debugging enabled..."
  DEBUG_PARAMS=" -Xdebug -Xrunjdwp:transport=dt_socket,address=1233,server=y,suspend=n"
else
  echo "JDWP debugging disabled..."
  DEBUG_PARAMS=""
fi

if [ ${TRACE_ENABLED} == "true" ]; then
  echo "OTEL enabled..."
  TRACE_PARAMS=" -javaagent:/usr/local/bin/aws-opentelemetry-agent.jar"
else
  echo "OTEL disabled..."
  TRACE_PARAMS=""
fi

export HOME="/home/oph"
export LOGS="${HOME}/logs"

echo "Using java options: ${JAVA_OPTS}"
echo "Using secret java options: ${SECRET_JAVA_OPTS}"

if [ `ls -l ${CATALINA_BASE}/webapps/ | wc -l` -ne 1 ]; then
    echo "Running tomcat war application..."
    echo "Creating setenv.sh..."
    cat > ${CATALINA_BASE}/bin/setenv.sh <<- SETENV
#!/bin/sh
export JAVA_OPTS="$JAVA_OPTS\
  ${SECRET_JAVA_OPTS}\
  -Duser.home=/home/oph\
  -Djavax.net.ssl.trustStore=${HOME}/cacerts\
  -Djava.util.logging.config.file=${LOGPATH}/logging.properties\
  -Djuli-logback.configurationFile=file://${LOGPATH}/logback-tomcat.xml\
  -DHOSTNAME=`hostname`\
  -Djava.net.preferIPv4Stack=true\
  -Dfile.encoding=UTF-8\
  -Djava.security.egd=file:/dev/urandom\
  -Dcom.sun.management.jmxremote\
  -Dcom.sun.management.jmxremote.authenticate=false\
  -Dcom.sun.management.jmxremote.ssl=false\
  -Dcom.sun.management.jmxremote.port=${JMX_PORT}\
  -Dcom.sun.management.jmxremote.rmi.port=${JMX_PORT}\
  -Dcom.sun.management.jmxremote.local.only=false\
  -Djava.rmi.server.hostname=localhost\
  -javaagent:/usr/local/bin/jmx_prometheus_javaagent.jar=1134:/etc/prometheus.yaml\
  ${TRACE_PARAMS}\
  -Xloggc:${LOGS}/${NAME}_gc.log\
  -XX:+PrintGCDetails\
  -XX:+PrintGCTimeStamps\
  -XX:+UseGCLogFileRotation\
  -XX:NumberOfGCLogFiles=10\
  -XX:GCLogFileSize=10m\
  -XX:+HeapDumpOnOutOfMemoryError\
  -XX:HeapDumpPath=/tmp/heap_dump.hprof\
  -XX:OnOutOfMemoryError='aws s3 mv /tmp/heap_dump.hprof s3://${ENV_NAME}-crash-dumps/${NAME}/`date +%F_%T`.hprof --no-progress ; kill -9 %p'\
  -XX:ErrorFile=/home/oph/logs/tomcat_hs_err.log\
  ${DEBUG_PARAMS}\
"
SETENV
    case ${NAME} in
      koski|sijoittelu-service|valinta|valintaperusteet-service|valintalaskenta|valintalaskentakoostepalvelu|dokumenttipalvelu|seuranta)
        echo "Skipped project's log4j.properties file."
        ;;
      *)
        echo "Using project's log4j.properties file."
        echo 'JAVA_OPTS="$JAVA_OPTS -Dlog4j.configuration=file:///home/oph/oph-configuration/log4j.properties"' >> ${CATALINA_BASE}/bin/setenv.sh
        ;;
    esac

    echo "Create common.properties"
    case ${NAME} in
      valinta|valinta-ui|valintaperusteet-service|sijoittelu-service)
        cp -fv ${BASEPATH}/oph-configuration/valinta.properties ${BASEPATH}/oph-configuration/common.properties
        ;;
      koski)
        echo "...skipped!"
        ;;
      *)
        cp -fv ${BASEPATH}/oph-configuration/${NAME}.properties ${BASEPATH}/oph-configuration/common.properties
        ;;
    esac

    # PP-277: Override tomcat server.xml with custom version to increase thread limit
    case ${NAME} in
      valinta)
        if [ -f "/home/oph/oph-configuration/valinta-tomcat-server.xml" ]; then
          echo "Overriding tomcat server.xml with custom version"
          cp -fv ${BASEPATH}/oph-configuration/valinta-tomcat-server.xml ${CATALINA_BASE}/conf/server.xml
        fi
        ;;
      *)
        echo "...skipped!"
        ;;
    esac

    echo "Create modified server.xml for eperusteet"
    case ${NAME} in
      eperusteet|eperusteet-amosaa|eperusteet-ylops|eperusteet-opintopolku)
        cp ${CONFIGPATH}/log/logback-access.xml ${CATALINA_BASE}/conf/
        cat > ${CATALINA_BASE}/conf/server.xml <<- SERVERXML
<?xml version='1.0' encoding='utf-8'?>
<Server port="8005" shutdown="SHUTDOWN">
  <Listener className="org.apache.catalina.core.AprLifecycleListener" SSLEngine="on" />
  <Listener className="org.apache.catalina.core.JasperListener" />
  <Listener className="org.apache.catalina.core.JreMemoryLeakPreventionListener" />
  <Listener className="org.apache.catalina.mbeans.GlobalResourcesLifecycleListener" />
  <Listener className="org.apache.catalina.core.ThreadLocalLeakPreventionListener" />

  <Service name="Catalina">

    <Connector port="8080" protocol="org.apache.coyote.http11.Http11NioProtocol" connectionTimeout="20000" secure="true" scheme="https"
               SSLEnabled="false" proxyPort="443" maxThreads="50" asyncTimeout="150000" URIEncoding="UTF-8"/>

    <Engine name="Catalina" defaultHost="localhost">

      <Host name="localhost"  appBase="webapps" unpackWARs="true" autoDeploy="true">
        <Valve className="ch.qos.logback.access.tomcat.LogbackValve" filename="conf/logback-access.xml" asyncSupported="true"/>
      </Host>
    </Engine>
  </Service>
</Server>
SERVERXML
        ;;
      *)
        echo "...skipped, not eperusteet!"
        ;;
    esac

    CONTEXT="/etc/oph/tomcat/conf/context.xml"
    if [ -f ${CONTEXT} ]; then
      echo "Create context.conf"
      j2 ${CONTEXT} ${VARS} > ${CATALINA_BASE}/conf/context.xml || true
    fi

    echo "Starting application..."
    cat ${CATALINA_BASE}/bin/setenv.sh
    exec ${CATALINA_HOME}/bin/catalina.sh run
else
  echo "Fatal error: No war found, exiting!"
  exit 1
fi
