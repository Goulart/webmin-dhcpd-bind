FROM ubuntu:xenial-20210114 AS add-apt-repositories

COPY pgpKeys/jcameron-key.asc /jcameron-key.asc

RUN apt-get update \
 && apt-key add /jcameron-key.asc \
 && rm -f /jcameron-key.asc \
 && echo "deb http://download.webmin.com/download/repository sarge contrib" >> /etc/apt/sources.list

FROM ubuntu:xenial-20210114

ENV ROOT_PASSWORD=password \
    WEBMIN_ENABLED=true \
    WEBMIN_INIT_SSL_ENABLED=true \
    WEBMIN_INIT_REDIRECT_PORT=10000 \
    WEBMIN_INIT_REFERERS=NONE \
    BIND_USER=bind \
    BIND_VERSION=9.10.3 \
    WEBMIN_VERSION=1.970 \
    DATA_DIR=/data \
    DHCPD_PROTOCOL=4

COPY --from=add-apt-repositories /etc/apt/trusted.gpg /etc/apt/trusted.gpg
COPY --from=add-apt-repositories /etc/apt/sources.list /etc/apt/sources.list

RUN rm -rf /etc/apt/apt.conf.d/docker-gzip-indexes \
 && apt-get -q -y update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
      bind9=1:${BIND_VERSION}* bind9-host=1:${BIND_VERSION}* dnsutils \
      webmin=${WEBMIN_VERSION}* \
 && apt-get -q -y -o "DPkg::Options::=--force-confold" -o "DPkg::Options::=--force-confdef" install apt-utils isc-dhcp-server man \
 && apt-get -q -y autoremove \
 && apt-get -q -y clean \
 && rm -rf /var/lib/apt/lists/*

EXPOSE 53/udp 53/tcp 67/udp 68/udp 67/tcp 68/tcp 10000/tcp

COPY util/entrypoint.sh /entrypoint.sh
COPY util/isc-dhcp-server.sh /etc/init.d/isc-dhcp-server
COPY util/etc-webmin-start.sh /etc/webmin/start
RUN chmod 755 /entrypoint.sh /etc/webmin/start /etc/init.d/isc-dhcp-server
RUN mkdir -p /etc/webmin

ENTRYPOINT ["/entrypoint.sh"]
#CMD ["/entrypoint.sh"]
