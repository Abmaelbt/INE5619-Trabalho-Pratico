# syntax=docker/dockerfile:1
ARG OS_BASE_IMAGE=registry.access.redhat.com/ubi9/ubi-minimal:9.5
ARG MAJOR_VERSION=7.2
ARG RELEASE=5
ARG ZBX_VERSION=${MAJOR_VERSION}.5
ARG BUILD_BASE_IMAGE=zabbix-build-pgsql:rhel-${ZBX_VERSION}

FROM ${BUILD_BASE_IMAGE} AS builder

ARG OS_BASE_IMAGE=registry.access.redhat.com/ubi9/ubi-minimal:9.5
FROM ${OS_BASE_IMAGE}

ARG MAJOR_VERSION
ARG RELEASE
ARG ZBX_VERSION
ARG ZBX_SOURCES=https://git.zabbix.com/scm/zbx/zabbix.git

ENV TERM=xterm \
    ZBX_VERSION=${ZBX_VERSION} ZBX_SOURCES=${ZBX_SOURCES} \
    ZABBIX_CONF_DIR="/etc/zabbix" \
    ZABBIX_WWW_ROOT="/usr/share/zabbix"

LABEL description="Zabbix web-interface based on Nginx web server with PostgreSQL database support" \
      maintainer="alexey.pustovalov@zabbix.com" \
      name="zabbix/zabbix-web-pgsql" \
      release="${RELEASE}" \
      run="docker run --name zabbix-web-nginx --link postgresql:pgsql-server --link zabbix-server:zabbix-server -p 80:80 -d registry.connect.redhat.com/zabbix/zabbix-web-pgsql-72:${ZBX_VERSION}" \
      summary="Zabbix web-interface based on Nginx web server with PostgreSQL database support" \
      url="https://www.zabbix.com/" \
      vendor="Zabbix SIA" \
      version="${MAJOR_VERSION}" \
      io.k8s.description="Zabbix web-interface based on Nginx web server with PostgreSQL database support" \
      io.k8s.display-name="Zabbix Frontend (Nginx)" \
      io.openshift.expose-services="8080:http,8443:https" \
      io.openshift.tags="zabbix,zabbix-web,pgsql,nginx" \
      org.label-schema.build-date="${BUILD_DATE}" \
      org.label-schema.description="Zabbix web-interface based on Nginx web server with PostgreSQL database support" \
      org.label-schema.docker.cmd="docker run --name zabbix-web-nginx --link postgresql:pgsql-server --link zabbix-server:zabbix-server -p 80:80 -d registry.connect.redhat.com/zabbix/zabbix-web-pgsql-72:${ZBX_VERSION}" \
      org.label-schema.license="AGPL v3.0" \
      org.label-schema.name="zabbix-web-pgsql-rhel" \
      org.label-schema.schema-version="1.0" \
      org.label-schema.url="https://zabbix.com/" \
      org.label-schema.usage="https://www.zabbix.com/documentation/${MAJOR_VERSION}/manual/installation/containers" \
      org.label-schema.vcs-ref="${VCS_REF}" \
      org.label-schema.vcs-url="${ZBX_SOURCES}" \
      org.label-schema.vendor="Zabbix SIA" \
      org.label-schema.version="${ZBX_VERSION}"

STOPSIGNAL SIGTERM

COPY ["licenses", "/licenses"]
COPY ["conf/etc/", "/etc/"]
COPY --from=builder ["/tmp/zabbix-${ZBX_VERSION}/ui", "${ZABBIX_WWW_ROOT}"]

RUN --mount=type=tmpfs,target=/var/lib/dnf/ \
    --mount=type=tmpfs,target=/var/cache/yum/ \
#    --mount=type=bind,target=/run/secrets/,src=secrets/ \
    set -eux && \
    INSTALL_PKGS="bash \
            curl-minimal \
            supervisor \
            shadow-utils \
            findutils \
            glibc-locale-source \
            nginx \
            postgresql \
            php-bcmath \
            php-curl \
            php-fpm \
            php-gd \
            php-json \
            php-ldap \
            php-mbstring \
            php-pgsql \
            php-xml" && \
    curl --tlsv1.2 -sSf -L https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm -o /tmp/epel-release-latest-9.noarch.rpm && \
    rpm -ivh /tmp/epel-release-latest-9.noarch.rpm && \
    rm -rf /tmp/epel-release-latest-9.noarch.rpm && \
    ARCH_SUFFIX="$(arch)"; \
    microdnf -y module enable \
        --disablerepo "*" \
        --enablerepo "rhel-9-for-$ARCH_SUFFIX-appstream-rpms" \
        --setopt=install_weak_deps=0 \
        --setopt=keepcache=0 \
        php:8.2 \
        postgresql:16 \
        nginx:1.24 && \
    microdnf -y install \
            --disablerepo "*" \
            --enablerepo "ubi-9-baseos-rpms" \
            --enablerepo "ubi-9-appstream-rpms" \
            --enablerepo "rhel-9-for-$ARCH_SUFFIX-baseos-rpms" \
            --enablerepo "rhel-9-for-$ARCH_SUFFIX-appstream-rpms" \
            --enablerepo "epel" \
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
            --home-dir /var/lib/zabbix/ \
        zabbix && \
    mkdir -p ${ZABBIX_CONF_DIR} && \
    mkdir -p ${ZABBIX_CONF_DIR}/web && \
    mkdir -p ${ZABBIX_CONF_DIR}/web/certs && \
    mkdir -p /var/lib/php/session && \
    rm -f /etc/nginx/conf.d/*.conf  && \
    rm -f /etc/php-fpm.conf.rpmnew && \
    rm -f /etc/php-fpm.d/www.conf && \
    ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    cd ${ZABBIX_WWW_ROOT}/ && \
    rm -f conf/zabbix.conf.php conf/maintenance.inc.php conf/zabbix.conf.php.example && \
    rm -rf tests && \
    rm -f locale/add_new_language.sh locale/update_po.sh locale/make_mo.sh && \
    find ${ZABBIX_WWW_ROOT}/locale -name '*.po' | xargs rm -f && \
    find ${ZABBIX_WWW_ROOT}/locale -name '*.sh' | xargs rm -f && \
    ln -s "${ZABBIX_CONF_DIR}/web/zabbix.conf.php" "${ZABBIX_WWW_ROOT}/conf/zabbix.conf.php" && \
    ln -s "${ZABBIX_CONF_DIR}/web/maintenance.inc.php" "${ZABBIX_WWW_ROOT}/conf/maintenance.inc.php" && \
    cat ${ZABBIX_WWW_ROOT}/include/locales.inc.php | grep display | grep true | awk '{$1=$1};1' | \
        cut -d"'" -f 2 | sort | \
        xargs -I '{}' bash -c 'echo "{}" && localedef -c -i {} -f UTF-8 {}.UTF-8 2>/dev/null' && \
    chown --quiet -R zabbix:root ${ZABBIX_CONF_DIR}/ ${ZABBIX_WWW_ROOT}/include/defines.inc.php ${ZABBIX_WWW_ROOT}/modules/ && \
    chgrp -R 0 ${ZABBIX_CONF_DIR}/ ${ZABBIX_WWW_ROOT}/include/defines.inc.php ${ZABBIX_WWW_ROOT}/modules/ && \
    chmod -R g=u ${ZABBIX_CONF_DIR}/ ${ZABBIX_WWW_ROOT}/include/defines.inc.php ${ZABBIX_WWW_ROOT}/modules/ && \
    chown --quiet -R zabbix:root /etc/nginx/ /etc/php-fpm.d/ /etc/php-fpm.conf /var/log/nginx/ && \
    chgrp -R 0 /etc/nginx/ /etc/php-fpm.d/ /etc/php-fpm.conf /var/log/nginx/ && \
    chmod -R g=u /etc/nginx/ /etc/php-fpm.d/ /etc/php-fpm.conf /var/log/nginx/ && \
    chown --quiet -R zabbix:root /var/lib/php/session/ && \
    chgrp -R 0 /var/lib/php/session/ && \
    chmod -R g=u /var/lib/php/session/ && \
    microdnf -y remove \
            findutils \
            glibc-locale-source

HEALTHCHECK --interval=1m30s --timeout=3s --retries=3 --start-period=40s --start-interval=5s \
    CMD curl -f http://localhost:8080/ping || exit 1

EXPOSE 8080/TCP 8443/TCP

WORKDIR ${ZABBIX_WWW_ROOT}

COPY ["docker-entrypoint.sh", "/usr/bin/"]

USER 1997

ENTRYPOINT ["docker-entrypoint.sh"]
