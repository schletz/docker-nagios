FROM ubuntu:20.04
MAINTAINER Jason Rivers <jason@jasonrivers.co.uk>

ENV NAGIOS_HOME            /opt/nagios
ENV NAGIOS_USER            nagios
ENV NAGIOS_GROUP           nagios
ENV NAGIOS_CMDUSER         nagios
ENV NAGIOS_CMDGROUP        nagios
ENV NAGIOS_FQDN            nagios.example.com
ENV NAGIOSADMIN_USER       nagiosadmin
ENV NAGIOSADMIN_PASS       nagios
ENV APACHE_RUN_USER        nagios
ENV APACHE_RUN_GROUP       nagios
ENV NAGIOS_TIMEZONE        UTC
ENV DEBIAN_FRONTEND        noninteractive
ENV NG_NAGIOS_CONFIG_FILE  ${NAGIOS_HOME}/etc/nagios.cfg
ENV NG_CGI_DIR             ${NAGIOS_HOME}/sbin
ENV NG_WWW_DIR             ${NAGIOS_HOME}/share/nagiosgraph
ENV NG_CGI_URL             /cgi-bin
ENV NAGIOS_BRANCH          nagios-4.4.11
ENV NAGIOS_PLUGINS_BRANCH  release-2.4.4

RUN echo postfix postfix/main_mailer_type string "'Internet Site'" | debconf-set-selections  && \
    echo postfix postfix/mynetworks string "127.0.0.0/8" | debconf-set-selections            && \
    echo postfix postfix/mailname string ${NAGIOS_FQDN} | debconf-set-selections             && \
    apt-get update && apt-get install -y    \
        apache2                             \
        apache2-utils                       \
        autoconf                            \
        automake                            \
        bc                                  \
        bsd-mailx                           \
        build-essential                     \
        dnsutils                            \
        fping                               \
        gettext                             \
        git                                 \
        gperf                               \
        iputils-ping                        \
        jq                                  \
        libapache2-mod-php                  \
        libcache-memcached-perl             \
        libcgi-pm-perl                      \
        libcrypt-des-perl                   \
        libcrypt-rijndael-perl              \
        libcrypt-x509-perl                  \
        libtext-glob-perl                   \
        libdbd-mysql-perl                   \
        libdbd-pg-perl                      \
        libdbi-dev                          \
        libdbi-perl                         \
        libdigest-hmac-perl                 \
        libfreeradius-dev                   \
        libgdchart-gd2-xpm-dev              \
        libgd-gd2-perl                      \
        libjson-perl                        \
        libldap2-dev                        \
        libmonitoring-plugin-perl           \
        libmysqlclient-dev                  \
        libnagios-object-perl               \
        libnet-snmp-perl                    \
        libnet-snmp-perl                    \
        libnet-tftp-perl                    \
        libnet-xmpp-perl                    \
        libpq-dev                           \
        libradsec-dev                       \
        libredis-perl                       \
        librrds-perl                        \
        libssl-dev                          \
        libswitch-perl                      \
        libwww-perl                         \
        m4                                  \
        netcat                              \
        parallel                            \
        php-cli                             \
        php-gd                              \
        postfix                             \
        python3-pip                         \
        python3-nagiosplugin                \
        rsync                               \
        rsyslog                             \
        runit                               \
        smbclient                           \
        snmp                                \
        snmpd                               \
        snmp-mibs-downloader                \
        unzip                               \
        python                              \
        net-tools                           \
                                         && \
    apt-get clean && rm -Rf /var/lib/apt/lists/*

RUN ( egrep -i "^${NAGIOS_GROUP}"    /etc/group || groupadd $NAGIOS_GROUP    )                         && \
    ( egrep -i "^${NAGIOS_CMDGROUP}" /etc/group || groupadd $NAGIOS_CMDGROUP )
RUN ( id -u $NAGIOS_USER    || useradd --system -d $NAGIOS_HOME -g $NAGIOS_GROUP    $NAGIOS_USER    )  && \
    ( id -u $NAGIOS_CMDUSER || useradd --system -d $NAGIOS_HOME -g $NAGIOS_CMDGROUP $NAGIOS_CMDUSER )

RUN cd /tmp                                                                          && \
    git clone https://github.com/NagiosEnterprises/nagioscore.git -b $NAGIOS_BRANCH  && \
    cd nagioscore                                                                    && \
    ./configure                                  \
        --prefix=${NAGIOS_HOME}                  \
        --exec-prefix=${NAGIOS_HOME}             \
        --enable-event-broker                    \
        --with-command-user=${NAGIOS_CMDUSER}    \
        --with-command-group=${NAGIOS_CMDGROUP}  \
        --with-nagios-user=${NAGIOS_USER}        \
        --with-nagios-group=${NAGIOS_GROUP}      \
                                                                                     && \
    make all                                                                         && \
    make install                                                                     && \
    make install-config                                                              && \
    make install-commandmode                                                         && \
    make install-webconf                                                             && \
    make clean                                                                       && \
    cd /tmp && rm -Rf nagioscore

RUN cd /tmp                                                                                   && \
    git clone https://github.com/nagios-plugins/nagios-plugins.git -b $NAGIOS_PLUGINS_BRANCH  && \
    cd nagios-plugins                                                                         && \
    ./tools/setup                                                                             && \
    ./configure                                                 \
        --prefix=${NAGIOS_HOME}                                 \
        --with-ipv6                                             \
        --with-ping-command="/usr/bin/ping -n -U -W %d -c %d %s"  \
        --with-ping6-command="/usr/bin/ping -6 -n -U -W %d -c %d %s"  \
                                                                                              && \
    make                                                                                      && \
    make install                                                                              && \
    make clean                                                                                && \
    mkdir -p /usr/lib/nagios/plugins                                                          && \
    ln -sf ${NAGIOS_HOME}/libexec/utils.pm /usr/lib/nagios/plugins                            && \
    chown root:root ${NAGIOS_HOME}/libexec/check_icmp                                         && \
    chmod u+s ${NAGIOS_HOME}/libexec/check_icmp                                               && \
    cd /tmp && rm -Rf nagios-plugins                                                          

RUN cd /tmp                                                          && \
    git clone https://git.code.sf.net/p/nagiosgraph/git nagiosgraph  && \
    cd nagiosgraph                                                   && \
    ./install.pl --install                                      \
        --prefix /opt/nagiosgraph                               \
        --nagios-user ${NAGIOS_USER}                            \
        --www-user ${NAGIOS_USER}                               \
        --nagios-perfdata-file ${NAGIOS_HOME}/var/perfdata.log  \
        --nagios-cgi-url /cgi-bin                               \
                                                                     && \
    cp share/nagiosgraph.ssi ${NAGIOS_HOME}/share/ssi/common-header.ssi && \
    cd /tmp && rm -Rf nagiosgraph

RUN sed -i.bak 's/.*\=www\-data//g' /etc/apache2/envvars
RUN export DOC_ROOT="DocumentRoot $(echo $NAGIOS_HOME/share)"                         && \
    sed -i "s,DocumentRoot.*,$DOC_ROOT," /etc/apache2/sites-enabled/000-default.conf  && \
    sed -i "s,</VirtualHost>,<IfDefine ENABLE_USR_LIB_CGI_BIN>\nScriptAlias /cgi-bin/ ${NAGIOS_HOME}/sbin/\n</IfDefine>\n</VirtualHost>," /etc/apache2/sites-enabled/000-default.conf  && \
    ln -s /etc/apache2/mods-available/cgi.load /etc/apache2/mods-enabled/cgi.load

RUN mkdir -p -m 0755 /usr/share/snmp/mibs                     && \
    mkdir -p         ${NAGIOS_HOME}/etc/conf.d                && \
    mkdir -p         ${NAGIOS_HOME}/etc/monitor               && \
    mkdir -p -m 700  ${NAGIOS_HOME}/.ssh                      && \
    chown ${NAGIOS_USER}:${NAGIOS_GROUP} ${NAGIOS_HOME}/.ssh  && \
    touch /usr/share/snmp/mibs/.foo                           && \
    ln -s /usr/share/snmp/mibs ${NAGIOS_HOME}/libexec/mibs    && \
    ln -s ${NAGIOS_HOME}/bin/nagios /usr/local/bin/nagios     && \
    download-mibs && echo "mibs +ALL" > /etc/snmp/snmp.conf

RUN sed -i 's,/bin/mail,/usr/bin/mail,' ${NAGIOS_HOME}/etc/objects/commands.cfg  && \
    sed -i 's,/usr/usr,/usr,'           ${NAGIOS_HOME}/etc/objects/commands.cfg

RUN cp /etc/services /var/spool/postfix/etc/  && \
    echo "smtp_address_preference = ipv4" >> /etc/postfix/main.cf

RUN rm -rf /etc/rsyslog.d /etc/rsyslog.conf

RUN rm -rf /etc/sv/getty-5

ADD overlay /

RUN echo "use_timezone=${NAGIOS_TIMEZONE}" >> ${NAGIOS_HOME}/etc/nagios.cfg


# Copy example config in-case the user has started with empty var or etc

RUN mkdir -p /orig/var                     && \
    mkdir -p /orig/etc                     && \
    cp -Rp ${NAGIOS_HOME}/var/* /orig/var/ && \
    cp -Rp ${NAGIOS_HOME}/etc/* /orig/etc/ && \
    chmod -R 777 ${NAGIOS_HOME}/etc

## Set the permissions for example config
RUN find /opt/nagios/etc \! -user ${NAGIOS_USER} -exec chown ${NAGIOS_USER}:${NAGIOS_GROUP} '{}' + && \
    find /orig/etc \! -user ${NAGIOS_USER} -exec chown ${NAGIOS_USER}:${NAGIOS_GROUP} '{}' +

RUN a2enmod session         && \
    a2enmod session_cookie  && \
    a2enmod session_crypto  && \
    a2enmod auth_form       && \
    a2enmod request

RUN chmod +x /usr/local/bin/start_nagios        && \
    chmod +x /etc/sv/apache/run                 && \
    chmod +x /etc/sv/nagios/run                 && \
    chmod +x /etc/sv/postfix/run                 && \
    chmod +x /etc/sv/rsyslog/run                 && \
    chmod +x /opt/nagiosgraph/etc/fix-nagiosgraph-multiple-selection.sh

RUN cd /opt/nagiosgraph/etc && \
    sh fix-nagiosgraph-multiple-selection.sh

RUN rm /opt/nagiosgraph/etc/fix-nagiosgraph-multiple-selection.sh

# enable all runit services
RUN ln -s /etc/sv/* /etc/service

# fix ping permissions for nagios user
RUN chmod u+s /usr/bin/ping

ENV APACHE_LOCK_DIR /var/run
ENV APACHE_LOG_DIR /var/log/apache2

#Set ServerName and timezone for Apache
RUN echo "ServerName ${NAGIOS_FQDN}" > /etc/apache2/conf-available/servername.conf    && \
    echo "PassEnv TZ" > /etc/apache2/conf-available/timezone.conf            && \
    ln -s /etc/apache2/conf-available/servername.conf /etc/apache2/conf-enabled/servername.conf    && \
    ln -s /etc/apache2/conf-available/timezone.conf /etc/apache2/conf-enabled/timezone.conf

EXPOSE 80 5667 

VOLUME "${NAGIOS_HOME}/var" "${NAGIOS_HOME}/etc" "/var/log/apache2" "/opt/Custom-Nagios-Plugins" "/opt/nagiosgraph/var" "/opt/nagiosgraph/etc"

CMD [ "/usr/local/bin/start_nagios" ]
