# syntax=docker/dockerfile:1
ARG MAJOR_VERSION=7.2
ARG RELEASE=5
ARG ZBX_VERSION=${MAJOR_VERSION}.5
ARG BUILD_BASE_IMAGE=zabbix-build-base:rhel-${ZBX_VERSION}

FROM ${BUILD_BASE_IMAGE} AS builder

ARG MAJOR_VERSION
ARG RELEASE
ARG ZBX_VERSION
ARG ZBX_SOURCES=https://git.zabbix.com/scm/zbx/zabbix.git
ARG GIT_BRANCH

ARG ZBX_PLUGINS_VERSION=${GIT_BRANCH:-$ZBX_VERSION}
ARG CFLAGS

LABEL description="Zabbix build base for MySQL based images" \
      maintainer="alexey.pustovalov@zabbix.com" \
      name="zabbix/zabbix-build-mysql-72" \
      release="${RELEASE}" \
      summary="Zabbix build base (MySQL)" \
      url="https://www.zabbix.com/" \
      vendor="Zabbix SIA" \
      version="${MAJOR_VERSION}" \
      io.k8s.description="Zabbix build base for MySQL based images" \
      io.k8s.display-name="Zabbix build base (MySQL)" \
      io.openshift.expose-services="" \
      io.openshift.tags="zabbix,build,mysql" \
      org.label-schema.description="Zabbix build base for MySQL based images" \
      org.label-schema.license="AGPL v3.0" \
      org.label-schema.name="zabbix-build-mysql-rhel" \
      org.label-schema.url="https://zabbix.com/" \
      org.label-schema.vcs-ref="${VCS_REF}" \
      org.label-schema.vendor="Zabbix SIA"

ENV ZBX_SOURCES_DIR=/tmp/zabbix-${ZBX_VERSION} ZBX_OUTPUT_DIR=/tmp/zabbix-${ZBX_VERSION}-output \
    DB_TYPE=mysql \
    CFLAGS=${CFLAGS:-"-fPIC -pie -Wl,-z,relro,-z,now,-z,defs -D_FORTIFY_SOURCE=2 -fexceptions -O2 -pipe"} \
    MONGODB_PLUGIN_SOURCES=https://git.zabbix.com/scm/ap/mongodb.git MONGODB_PLUGIN_VERSION=${ZBX_PLUGINS_VERSION} \
    POSTGRESQL_PLUGIN_SOURCES=https://git.zabbix.com/scm/ap/postgresql.git POSTGRESQL_PLUGIN_VERSION=${ZBX_PLUGINS_VERSION} \
    MSSQL_PLUGIN_SOURCES=https://git.zabbix.com/scm/ap/mssql.git MSSQL_PLUGIN_VERSION=${ZBX_PLUGINS_VERSION} \
    EMBER_PLUS_PLUGIN_SOURCES=https://git.zabbix.com/scm/ap/ember-plus.git EMBER_PLUS_PLUGIN_VERSION=${ZBX_PLUGINS_VERSION} \
    NVIDIA_GPU_PLUGIN_SOURCES=https://git.zabbix.com/scm/ap/nvidia-gpu.git NVIDIA_GPU_PLUGIN_VERSION=${ZBX_PLUGINS_VERSION}

RUN --mount=type=cache,target=/root/.cache/go-build/ \
    --mount=type=cache,target=/root/go/ \
    --mount=from=sources,target=/tmp/src \
    --mount=type=bind,source=patches/,target=/tmp/patches \
    --mount=from=config_templates,target=/tmp/conf \
    set -eux && \
    cd /tmp/ && \
    mkdir -p ${ZBX_OUTPUT_DIR}/agent/sbin/ && \
    mkdir -p ${ZBX_OUTPUT_DIR}/agent/conf/ && \
    mkdir -p ${ZBX_OUTPUT_DIR}/agent2/sbin/ && \
    mkdir -p ${ZBX_OUTPUT_DIR}/agent2/conf/ && \
    mkdir -p ${ZBX_OUTPUT_DIR}/agent2/conf/zabbix_agent2.d/plugins.d/ && \
    mkdir -p ${ZBX_OUTPUT_DIR}/proxy/sbin/ && \
    mkdir -p ${ZBX_OUTPUT_DIR}/proxy/conf/ && \
    mkdir -p ${ZBX_OUTPUT_DIR}/proxy/database/${DB_TYPE}/ && \
    mkdir -p ${ZBX_OUTPUT_DIR}/server/sbin/ && \
    mkdir -p ${ZBX_OUTPUT_DIR}/server/conf/ && \
    mkdir -p ${ZBX_OUTPUT_DIR}/server/database/${DB_TYPE}/ && \
    mkdir -p ${ZBX_OUTPUT_DIR}/java_gateway/sbin/ && \
    mkdir -p ${ZBX_OUTPUT_DIR}/web_service/sbin/ && \
    mkdir -p ${ZBX_OUTPUT_DIR}/web_service/conf/ && \
    mkdir -p ${ZBX_OUTPUT_DIR}/general/sbin/ && \
    mkdir -p ${ZBX_OUTPUT_DIR}/general/bin/ && \
    mkdir -p ${ZBX_OUTPUT_DIR}/general/conf/ && \
    if [ -f "/tmp/src/bootstrap.sh" ]; then \
        cp -R /tmp/src ${ZBX_SOURCES_DIR}; \
    else \
        git -c advice.detachedHead=false clone ${ZBX_SOURCES} --branch ${GIT_BRANCH:-$ZBX_VERSION} --depth 1 --single-branch ${ZBX_SOURCES_DIR}; \
    fi && \
    cd ${ZBX_SOURCES_DIR} && \
    for patch_filename in /tmp/patches/*.patch; do \
        if [ -f "$patch_filename" ]; then \
            patch -p1 < $patch_filename; \
        fi \
    done && \
    zabbix_revision=`git rev-parse --short HEAD` && \
    sed -i "s/{ZABBIX_REVISION}/$zabbix_revision/g" include/version.h && \
    sed -i "s/{ZABBIX_REVISION}/$zabbix_revision/g" src/go/pkg/version/version.go && \
    sed -i "s/{ZABBIX_REVISION}/$zabbix_revision/g" src/zabbix_java/src/com/zabbix/gateway/GeneralInformation.java && \
    ./bootstrap.sh && \
    ./configure \
            --datadir=/usr/lib \
            --libdir=/usr/lib/zabbix \
            --prefix=/usr \
            --sysconfdir=/etc/zabbix \
            --enable-ipv6 \
            --enable-agent \
            --enable-agent2 \
            --enable-java \
            --enable-proxy \
            --enable-server \
            --enable-webservice \
            --with-ldap \
            --with-libcurl \
            --with-libmodbus \
            --with-libpcre2 \
            --with-libxml2 \
            --with-${DB_TYPE} \
            --with-net-snmp \
            --with-openipmi \
            --with-openssl \
            --with-ssh \
            --with-unixodbc \
            --silent && \
    make -s dbschema && \
    make -j"$(nproc)" -s && \
    make -s gettext && \
    cat database/${DB_TYPE}/schema.sql > database/${DB_TYPE}/create.sql && \
    gzip -c database/${DB_TYPE}/create.sql > ${ZBX_OUTPUT_DIR}/proxy/database/${DB_TYPE}/create.sql.gz && \
    cat database/${DB_TYPE}/images.sql >> database/${DB_TYPE}/create.sql && \
    cat database/${DB_TYPE}/data.sql >> database/${DB_TYPE}/create.sql && \
    gzip -c database/${DB_TYPE}/create.sql > ${ZBX_OUTPUT_DIR}/server/database/${DB_TYPE}/create.sql.gz && \
    rm -rf database/${DB_TYPE}/create.sql && \
    mkdir /tmp/fonts/ && \
    curl --tlsv1.2 -sSf -L "https://noto-website-2.storage.googleapis.com/pkgs/NotoSansCJKjp-hinted.zip" -o /tmp/fonts/NotoSansCJKjp-hinted.zip && \
    unzip /tmp/fonts/NotoSansCJKjp-hinted.zip -d /tmp/fonts/ && \
    cp /tmp/fonts/NotoSansCJKjp-Regular.otf ${ZBX_SOURCES_DIR}/ui/assets/fonts/NotoSansCJKjp-Regular.ttf && \
    cp /tmp/fonts/LICENSE_OFL.txt ${ZBX_SOURCES_DIR}/ui/assets/fonts/ && \
    rm -f ${ZBX_SOURCES_DIR}/ui/assets/fonts/DejaVuSans.ttf && \
    sed -i -r "s/(define\(.*_FONT_NAME.*)DejaVuSans/\1NotoSansCJKjp-Regular/" ${ZBX_SOURCES_DIR}/ui/include/defines.inc.php && \
    rm -rf /tmp/fonts/ && \
    chmod o+r ${ZBX_SOURCES_DIR}/ui/assets/fonts/* && \
    strip ${ZBX_SOURCES_DIR}/src/zabbix_agent/zabbix_agentd && \
    strip ${ZBX_SOURCES_DIR}/src/zabbix_server/zabbix_server && \
    strip ${ZBX_SOURCES_DIR}/src/zabbix_proxy/zabbix_proxy && \
    strip ${ZBX_SOURCES_DIR}/src/go/bin/zabbix_agent2 && \
    strip ${ZBX_SOURCES_DIR}/src/zabbix_get/zabbix_get && \
    strip ${ZBX_SOURCES_DIR}/src/zabbix_sender/zabbix_sender && \
    strip ${ZBX_SOURCES_DIR}/src/go/bin/zabbix_web_service && \
    cp ${ZBX_SOURCES_DIR}/src/zabbix_agent/zabbix_agentd ${ZBX_OUTPUT_DIR}/agent/sbin/ && \
    cp ${ZBX_SOURCES_DIR}/conf/zabbix_agentd.conf ${ZBX_OUTPUT_DIR}/agent/conf/zabbix_agentd.conf_template && \
    cp -R ${ZBX_SOURCES_DIR}/conf/zabbix_agentd/ ${ZBX_OUTPUT_DIR}/agent/conf/ && \
    cp /tmp/conf/agent/* ${ZBX_OUTPUT_DIR}/agent/conf/ && \
    cp ${ZBX_SOURCES_DIR}/src/go/bin/zabbix_agent2 ${ZBX_OUTPUT_DIR}/agent2/sbin/ && \
    cp ${ZBX_SOURCES_DIR}/src/go/conf/zabbix_agent2.conf ${ZBX_OUTPUT_DIR}/agent2/conf/zabbix_agent2.conf_template && \
    cp /tmp/conf/agent2/* ${ZBX_OUTPUT_DIR}/agent2/conf/ && \
    cp -R ${ZBX_SOURCES_DIR}/src/go/conf/zabbix_agent2.d/ ${ZBX_OUTPUT_DIR}/agent2/conf/ && \
    cp ${ZBX_SOURCES_DIR}/src/zabbix_server/zabbix_server ${ZBX_OUTPUT_DIR}/server/sbin/ && \
    cp ${ZBX_SOURCES_DIR}/conf/zabbix_server.conf ${ZBX_OUTPUT_DIR}/server/conf/zabbix_server.conf_template && \
    cp /tmp/conf/server/* ${ZBX_OUTPUT_DIR}/server/conf/ && \
    cp ${ZBX_SOURCES_DIR}/src/zabbix_proxy/zabbix_proxy ${ZBX_OUTPUT_DIR}/proxy/sbin/ && \
    cp ${ZBX_SOURCES_DIR}/conf/zabbix_proxy.conf ${ZBX_OUTPUT_DIR}/proxy/conf/zabbix_proxy.conf_template && \
    cp /tmp/conf/proxy/* ${ZBX_OUTPUT_DIR}/proxy/conf/ && \
    cp -R ${ZBX_SOURCES_DIR}/src/zabbix_java/bin/ ${ZBX_OUTPUT_DIR}/java_gateway/sbin/ && \
    cp -R ${ZBX_SOURCES_DIR}/src/zabbix_java/lib/ ${ZBX_OUTPUT_DIR}/java_gateway/sbin/ && \
    cp ${ZBX_SOURCES_DIR}/src/go/bin/zabbix_web_service ${ZBX_OUTPUT_DIR}/web_service/sbin/ && \
    cp ${ZBX_SOURCES_DIR}/src/go/conf/zabbix_web_service.conf ${ZBX_OUTPUT_DIR}/web_service/conf/zabbix_web_service.conf_template && \
    cp /tmp/conf/web_service/* ${ZBX_OUTPUT_DIR}/web_service/conf/ && \
    cp ${ZBX_SOURCES_DIR}/src/zabbix_get/zabbix_get ${ZBX_OUTPUT_DIR}/general/bin/ && \
    cp ${ZBX_SOURCES_DIR}/src/zabbix_sender/zabbix_sender ${ZBX_OUTPUT_DIR}/general/bin/ && \
    make -s distclean && \
    cd /tmp/ && \
    mkdir -p ${ZBX_OUTPUT_DIR}/agent2/sbin/zabbix-agent2-plugin/ && \
    mkdir -p ${ZBX_OUTPUT_DIR}/agent2/conf/zabbix_agent2.d/plugins.d/ && \
    git -c advice.detachedHead=false clone ${MONGODB_PLUGIN_SOURCES} --branch ${MONGODB_PLUGIN_VERSION} --depth 1 --single-branch /tmp/mongodb-plugin-${MONGODB_PLUGIN_VERSION} && \
    cd /tmp/mongodb-plugin-${MONGODB_PLUGIN_VERSION} && \
    make && \
    strip /tmp/mongodb-plugin-${MONGODB_PLUGIN_VERSION}/zabbix-agent2-plugin-mongodb && \
    cp /tmp/mongodb-plugin-${MONGODB_PLUGIN_VERSION}/zabbix-agent2-plugin-mongodb ${ZBX_OUTPUT_DIR}/agent2/sbin/zabbix-agent2-plugin/mongodb && \
    cp /tmp/mongodb-plugin-${MONGODB_PLUGIN_VERSION}/mongodb.conf ${ZBX_OUTPUT_DIR}/agent2/conf/zabbix_agent2.d/plugins.d/ && \
    cd /tmp/ && \
    git -c advice.detachedHead=false clone ${POSTGRESQL_PLUGIN_SOURCES} --branch ${POSTGRESQL_PLUGIN_VERSION} --depth 1 --single-branch /tmp/postgresql-plugin-${POSTGRESQL_PLUGIN_VERSION} && \
    cd /tmp/postgresql-plugin-${POSTGRESQL_PLUGIN_VERSION} && \
    make && \
    strip /tmp/postgresql-plugin-${POSTGRESQL_PLUGIN_VERSION}/zabbix-agent2-plugin-postgresql && \
    cp /tmp/postgresql-plugin-${POSTGRESQL_PLUGIN_VERSION}/zabbix-agent2-plugin-postgresql ${ZBX_OUTPUT_DIR}/agent2/sbin/zabbix-agent2-plugin/postgresql && \
    cp /tmp/postgresql-plugin-${POSTGRESQL_PLUGIN_VERSION}/postgresql.conf ${ZBX_OUTPUT_DIR}/agent2/conf/zabbix_agent2.d/plugins.d/ && \
    cd /tmp/ && \
    git -c advice.detachedHead=false clone ${MSSQL_PLUGIN_SOURCES} --branch ${MSSQL_PLUGIN_VERSION} --depth 1 --single-branch /tmp/mssql-plugin-${MSSQL_PLUGIN_VERSION} && \
    cd /tmp/mssql-plugin-${MSSQL_PLUGIN_VERSION} && \
    make && \
    strip /tmp/mssql-plugin-${MSSQL_PLUGIN_VERSION}/zabbix-agent2-plugin-mssql && \
    cp /tmp/mssql-plugin-${MSSQL_PLUGIN_VERSION}/zabbix-agent2-plugin-mssql ${ZBX_OUTPUT_DIR}/agent2/sbin/zabbix-agent2-plugin/mssql && \
    cp /tmp/mssql-plugin-${MSSQL_PLUGIN_VERSION}/mssql.conf ${ZBX_OUTPUT_DIR}/agent2/conf/zabbix_agent2.d/plugins.d/ && \
    cd /tmp/ && \
    git -c advice.detachedHead=false clone ${EMBER_PLUS_PLUGIN_SOURCES} --branch ${EMBER_PLUS_PLUGIN_VERSION} --depth 1 --single-branch /tmp/ember-plugin-${EMBER_PLUS_PLUGIN_VERSION} && \
    cd /tmp/ember-plugin-${EMBER_PLUS_PLUGIN_VERSION} && \
    make && \
    strip /tmp/ember-plugin-${EMBER_PLUS_PLUGIN_VERSION}/zabbix-agent2-plugin-ember-plus && \
    cp /tmp/ember-plugin-${EMBER_PLUS_PLUGIN_VERSION}/zabbix-agent2-plugin-ember-plus ${ZBX_OUTPUT_DIR}/agent2/sbin/zabbix-agent2-plugin/ember-plus && \
    cp /tmp/ember-plugin-${EMBER_PLUS_PLUGIN_VERSION}/ember.conf ${ZBX_OUTPUT_DIR}/agent2/conf/zabbix_agent2.d/plugins.d/ && \
    cd /tmp/ && \
    git -c advice.detachedHead=false clone ${NVIDIA_GPU_PLUGIN_SOURCES} --branch ${NVIDIA_GPU_PLUGIN_VERSION} --depth 1 --single-branch /tmp/nvidia-gpu-plugin-${NVIDIA_GPU_PLUGIN_VERSION} && \
    cd /tmp/nvidia-gpu-plugin-${NVIDIA_GPU_PLUGIN_VERSION} && \
    make && \
    strip /tmp/nvidia-gpu-plugin-${NVIDIA_GPU_PLUGIN_VERSION}/zabbix-agent2-plugin-nvidia-gpu && \
    cp /tmp/nvidia-gpu-plugin-${NVIDIA_GPU_PLUGIN_VERSION}/zabbix-agent2-plugin-nvidia-gpu ${ZBX_OUTPUT_DIR}/agent2/sbin/zabbix-agent2-plugin/nvidia-gpu && \
    cp /tmp/nvidia-gpu-plugin-${NVIDIA_GPU_PLUGIN_VERSION}/nvidia.conf ${ZBX_OUTPUT_DIR}/agent2/conf/zabbix_agent2.d/plugins.d/
