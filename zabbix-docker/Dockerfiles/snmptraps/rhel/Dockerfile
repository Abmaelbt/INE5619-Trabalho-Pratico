# syntax=docker/dockerfile:1
ARG OS_BASE_IMAGE=registry.access.redhat.com/ubi9/ubi-minimal:9.5
FROM ${OS_BASE_IMAGE}

ARG MAJOR_VERSION=7.2
ARG RELEASE=5
ARG ZBX_VERSION=${MAJOR_VERSION}.5

ARG ZBX_SOURCES=https://git.zabbix.com/scm/zbx/zabbix.git

ENV TERM=xterm \
    ZBX_VERSION=${ZBX_VERSION} ZBX_SOURCES=${ZBX_SOURCES} \
    MIBDIRS=/usr/share/snmp/mibs:/var/lib/zabbix/mibs MIBS=+ALL \
    ZBX_SNMP_TRAP_DATE_FORMAT=+%Y-%m-%dT%T%z ZBX_SNMP_TRAP_FORMAT="\n" \
    ZBX_SNMP_TRAP_USE_DNS=false \
    ZABBIX_USER_HOME_DIR="/var/lib/zabbix"

ENV SNMP_PERSISTENT_DIR="${ZABBIX_USER_HOME_DIR}/snmptrapd_config"

LABEL description="Zabbix SNMP traps receiver" \
      maintainer="alexey.pustovalov@zabbix.com" \
      name="zabbix/zabbix-snmptraps-72" \
      release="${RELEASE}" \
      run="docker run --name zabbix-snmptraps --link zabbix-server:zabbix-server -p 162:1162/udp -d registry.connect.redhat.com/zabbix/zabbix-snmptraps-72:${ZBX_VERSION}" \
      summary="Zabbix SNMP traps receiver" \
      url="https://www.zabbix.com/" \
      vendor="Zabbix SIA" \
      version="${MAJOR_VERSION}" \
      io.k8s.description="Zabbix SNMP traps receiver" \
      io.k8s.display-name="Zabbix SNMP traps receiver" \
      io.openshift.expose-services="162:1162" \
      io.openshift.tags="zabbix,zabbix-snmp,snmp-traps" \
      org.label-schema.build-date="${BUILD_DATE}" \
      org.label-schema.description="Zabbix SNMP traps receiver" \
      org.label-schema.docker.cmd="docker run --name zabbix-snmptraps --link zabbix-server:zabbix-server -p 162:1162/udp -d registry.connect.redhat.com/zabbix/zabbix-snmptraps-72:${ZBX_VERSION}" \
      org.label-schema.license="AGPL v3.0" \
      org.label-schema.name="zabbix-snmptraps-rhel" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://zabbix.com/" \
      org.label-schema.usage="https://www.zabbix.com/documentation/${MAJOR_VERSION}/manual/installation/containers" \
      org.label-schema.vcs-ref="${VCS_REF}" \
      org.label-schema.vcs-url="${ZBX_SOURCES}" \
      org.label-schema.vendor="Zabbix SIA" \
      org.label-schema.version="${ZBX_VERSION}"

STOPSIGNAL SIGTERM

COPY ["licenses", "/licenses"]

RUN --mount=type=tmpfs,target=/var/lib/dnf/ \
    --mount=type=tmpfs,target=/var/cache/yum/ \
    set -eux && \
    INSTALL_PKGS="bash \
            shadow-utils \
            net-snmp" && \
    microdnf -y install \
            --disableplugin=subscription-manager \
            --disablerepo="*" \
            --enablerepo "ubi-9-baseos-rpms" \
            --enablerepo "ubi-9-appstream-rpms" \
            --setopt=install_weak_deps=0 \
            --setopt=keepcache=0 \
            --best \
            --setopt=tsflags=nodocs \
        ${INSTALL_PKGS} && \
    microdnf -y update \
            --disableplugin=subscription-manager \
            --disablerepo "*" \
            --enablerepo "ubi-9-baseos-rpms" \
            --setopt=install_weak_deps=0 \
            --best \
            --setopt=tsflags=nodocs \
        tzdata && \
    microdnf -y reinstall \
            --disableplugin=subscription-manager \
            --disablerepo "*" \
            --enablerepo "ubi-9-baseos-rpms" \
            --setopt=install_weak_deps=0 \
            --setopt=keepcache=0 \
            --best \
            --setopt=tsflags=nodocs \
        tzdata && \
    groupadd \
            --system \
            --gid 1995 \
        zabbix && \
    useradd \
            --system \
            --comment "Zabbix monitoring system" \
            -g zabbix \
            --uid 1997 \
            --shell /sbin/nologin \
            --home-dir ${ZABBIX_USER_HOME_DIR} \
        zabbix && \
    mkdir -p ${ZABBIX_USER_HOME_DIR} && \
    mkdir -p ${ZABBIX_USER_HOME_DIR}/snmptraps && \
    mkdir -p ${ZABBIX_USER_HOME_DIR}/mibs && \
    mkdir -p ${SNMP_PERSISTENT_DIR} && \
    chown --quiet -R zabbix:root /etc/snmp/ ${ZABBIX_USER_HOME_DIR}/ /var/tmp/ /var/run/ && \
    chgrp -R 0 /etc/snmp/ ${ZABBIX_USER_HOME_DIR}/ /var/tmp/ /var/run/ && \
    chmod -R g=u /etc/snmp/ ${ZABBIX_USER_HOME_DIR}/ /var/tmp/ /var/run/

EXPOSE 1162/UDP

WORKDIR ${ZABBIX_USER_HOME_DIR}/snmptraps/

VOLUME ["${ZABBIX_USER_HOME_DIR}/snmptraps", "${SNMP_PERSISTENT_DIR}"]

COPY ["conf/etc/logrotate.d/zabbix_snmptraps", "/etc/logrotate.d/"]
COPY ["conf/etc/snmp/snmptrapd.conf", "/etc/snmp/"]
COPY ["conf/usr/sbin/zabbix_trap_handler.sh", "/usr/sbin/"]

USER 1997

CMD ["/usr/sbin/snmptrapd", "-n", "-t", "-X", "-C", "-c", "/etc/snmp/snmptrapd.conf", "-Lo", "-A", "--doNotFork=yes"]
