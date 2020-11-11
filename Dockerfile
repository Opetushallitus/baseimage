ARG OPENJDK_VERSION
ARG SERVICE_KIND

FROM golang:1.14-alpine as ssmbuilder
ARG SSM_AGENT_VERSION=2.3.930.0
RUN set -ex && apk add --no-cache make git gcc libc-dev curl bash && \
    curl -sLO https://github.com/aws/amazon-ssm-agent/archive/${SSM_AGENT_VERSION}.tar.gz && \
    mkdir -p /go/src/github.com && \
    tar xzf ${SSM_AGENT_VERSION}.tar.gz && \
    mv amazon-ssm-agent-${SSM_AGENT_VERSION} /go/src/github.com/amazon-ssm-agent && \
    cd /go/src/github.com/amazon-ssm-agent && \
    echo ${SSM_AGENT_VERSION} > /go/src/github.com/amazon-ssm-agent/SSM_AGENT_VERSION && \
    gofmt -w agent && make checkstyle || ./Tools/bin/goimports -w agent && \
    make build-linux

FROM adoptopenjdk/${OPENJDK_VERSION}:alpine-slim
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

COPY ci-tools/ssm_agent/ssm_agent.py /usr/local/bin
COPY ci-tools/ssm_agent/requirements.txt /tmp
RUN apk add musl-dev python3-dev gcc linux-headers && \
    pip3 install -r /tmp/requirements.txt && \
    apk add fontconfig ttf-dejavu && \
    apk del musl-dev python3-dev gcc linux-headers
RUN set -ex && apk add --no-cache sudo ca-certificates && \
    adduser -D ssm-user && echo "ssm-user ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ssm-agent-users && \
    echo "oph ALL=(ALL:ALL) NOPASSWD: /usr/bin/amazon-ssm-agent" >> /etc/sudoers && \
    mkdir -p /etc/amazon/ssm
COPY --from=ssmbuilder /go/src/github.com/amazon-ssm-agent/bin/linux_amd64/ /usr/bin
COPY --from=ssmbuilder /go/src/github.com/amazon-ssm-agent/bin/amazon-ssm-agent.json.template /etc/amazon/ssm/amazon-ssm-agent.json
COPY --from=ssmbuilder /go/src/github.com/amazon-ssm-agent/bin/seelog_unix.xml /etc/amazon/ssm/seelog.xml
RUN ln -s /tmp/log/amazon /var/log/amazon && ln -s /tmp/lib/amazon /var/lib/amazon

RUN echo "Remove /root and symlink /root to /home/oph for backwards compatibility"
RUN rm -rf /root && \
    ln -s /home/oph /root && \
    chown oph:oph -h /root
