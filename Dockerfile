ARG OPENJDK_VERSION
FROM amazoncorretto:${OPENJDK_VERSION}-alpine as corretto-jdk

RUN apk add --no-cache binutils

RUN $JAVA_HOME/bin/jlink \
         --verbose \
         --add-modules ALL-MODULE-PATH \
         --strip-debug \
         --no-man-pages \
         --no-header-files \
         --compress=2 \
         --output /customjre

FROM alpine:3.17

# need to repeat the argument declaration after FROM for it to be back in scope
ARG OPENJDK_VERSION
ARG SERVICE_KIND
ARG TOMCAT_VERSION
ARG FOLDER

ENV JAVA_HOME="/usr/lib/jvm/java-${OPENJDK_VERSION}-corretto"
ENV JRE_HOME="/usr/lib/jvm/java-${OPENJDK_VERSION}-corretto"
ENV PATH="${PATH}:/usr/lib/jvm/java-${OPENJDK_VERSION}-corretto/bin"

COPY --from=corretto-jdk /customjre $JAVA_HOME

RUN addgroup -S oph -g 1001 && adduser -u 1001 -D -G oph oph

COPY common/dump_threads.sh /usr/local/bin/
COPY variants/${FOLDER}/run.sh /usr/local/bin/run

# These are actually only used in case SERVICE_KIND = war:
COPY tomcat-files/${TOMCAT_VERSION}/server.xml /tmp/tomcat/conf/
COPY tomcat-files/${TOMCAT_VERSION}/ehcache.xml /etc/oph/oph-configuration/
COPY tomcat-files/${TOMCAT_VERSION}/jars/*.jar /tmp/tomcat/lib/

WORKDIR /root/
COPY variants/${FOLDER}/install.sh ./
COPY variants/${FOLDER}/test.sh ./
RUN \
  sh install.sh && \
  sh test.sh && \
  rm *.sh

RUN echo "Remove /root and symlink /root to /home/oph for backwards compatibility"
RUN rm -rf /root && \
    ln -s /home/oph /root && \
    chown oph:oph -h /root