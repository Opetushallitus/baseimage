ARG OPENJDK_VERSION
FROM adoptopenjdk/${OPENJDK_VERSION}:alpine-slim

# need to repeat the argument declaration after FROM for it to be back in scope
ARG OPENJDK_VERSION
ARG SERVICE_KIND

RUN addgroup -S oph -g 1001 && adduser -u 1001 -S -G oph oph

COPY common/dump_threads.sh /usr/local/bin/
COPY variants/${SERVICE_KIND}-${OPENJDK_VERSION}/run.sh /usr/local/bin/run

# These are actually only used in case SERVICE_KIND = war:
COPY tomcat-files/server.xml /tmp/tomcat/conf/
COPY tomcat-files/ehcache.xml /etc/oph/oph-configuration/
COPY tomcat-files/jars/*.jar /tmp/tomcat/lib/

WORKDIR /root/
COPY variants/${SERVICE_KIND}-${OPENJDK_VERSION}/install.sh ./
COPY variants/${SERVICE_KIND}-${OPENJDK_VERSION}/test.sh ./
RUN \
  sh install.sh && \
  sh test.sh && \
  rm *.sh

RUN apk add fontconfig ttf-dejavu

RUN echo "Remove /root and symlink /root to /home/oph for backwards compatibility"
RUN rm -rf /root && \
    ln -s /home/oph /root && \
    chown oph:oph -h /root