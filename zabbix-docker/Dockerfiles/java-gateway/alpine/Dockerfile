# syntax=docker/dockerfile:1
ARG OS_BASE_IMAGE=alpine:3.21
ARG MAJOR_VERSION=7.2
ARG ZBX_VERSION=${MAJOR_VERSION}.5
ARG BUILD_BASE_IMAGE=zabbix-build-mysql:alpine-${ZBX_VERSION}

FROM ${BUILD_BASE_IMAGE} AS builder

FROM ${OS_BASE_IMAGE}

ARG MAJOR_VERSION
ARG ZBX_VERSION
ARG ZBX_SOURCES=https://git.zabbix.com/scm/zbx/zabbix.git

ENV TERM=xterm \
    ZBX_VERSION=${ZBX_VERSION} ZBX_SOURCES=${ZBX_SOURCES} \
    PATH=${PATH}:/usr/lib/jvm/default-jvm/bin/ JAVA_HOME=/usr/lib/jvm/default-jvm \
    ZABBIX_USER_HOME_DIR="/var/lib/zabbix" \
    ZABBIX_CONF_DIR="/etc/zabbix"

LABEL org.opencontainers.image.authors="Alexey Pustovalov <alexey.pustovalov@zabbix.com>" \
      org.opencontainers.image.description="Zabbix Java Gateway performs native support for monitoring JMX applications" \
      org.opencontainers.image.documentation="https://www.zabbix.com/documentation/${MAJOR_VERSION}/manual/installation/containers" \
      org.opencontainers.image.licenses="AGPL v3.0" \
      org.opencontainers.image.source="${ZBX_SOURCES}" \
      org.opencontainers.image.title="Zabbix Java Gateway" \
      org.opencontainers.image.url="https://zabbix.com/" \
      org.opencontainers.image.vendor="Zabbix SIA" \
      org.opencontainers.image.version="${ZBX_VERSION}"

STOPSIGNAL SIGTERM

COPY --from=builder ["/tmp/zabbix-${ZBX_VERSION}-output/java_gateway/sbin/", "/usr/sbin/zabbix_java/"]

RUN set -eux && \
    ARCH_SUFFIX="$(cat /etc/apk/arch)"; \
    case "$ARCH_SUFFIX" in \
        riscv64) \
            openjdk_packages='openjdk21 openjdk21-jre-headless'; \
            ;; \
        *) openjdk_packages='openjdk17-jre-headless'; \
    esac; \
    INSTALL_PKGS="bash \
            $openjdk_packages" && \
    apk add \
            --no-cache \
            --clean-protected \
        ${INSTALL_PKGS} && \
    addgroup \
            --system \
            --gid 1995 \
        zabbix && \
    adduser \
            --system \
            --gecos "Zabbix monitoring system" \
            --disabled-password \
            --uid 1997 \
            --ingroup zabbix \
            --shell /sbin/nologin \
            --home ${ZABBIX_USER_HOME_DIR} \
        zabbix && \
    mkdir -p ${ZABBIX_CONF_DIR}/ && \
    mkdir -p /usr/sbin/zabbix_java/ext_lib/ && \
    rm -rf /usr/sbin/zabbix_java/lib/logback.xml && \
    mv /usr/sbin/zabbix_java/lib/logback-console.xml ${ZABBIX_CONF_DIR}/zabbix_java_gateway_logback.xml && \
    chown --quiet -R zabbix:root ${ZABBIX_CONF_DIR}/ /usr/sbin/zabbix_java/ && \
    chgrp -R 0 ${ZABBIX_CONF_DIR}/ /usr/sbin/zabbix_java/ && \
    chmod -R g=u ${ZABBIX_CONF_DIR}/ /usr/sbin/zabbix_java/

EXPOSE 10052/TCP

WORKDIR ${ZABBIX_USER_HOME_DIR}

COPY ["conf/usr/sbin/zabbix_java_gateway", "/usr/sbin/"]
COPY ["docker-entrypoint.sh", "/usr/bin/"]

ENTRYPOINT ["docker-entrypoint.sh"]

USER 1997

CMD ["/usr/sbin/zabbix_java_gateway"]
