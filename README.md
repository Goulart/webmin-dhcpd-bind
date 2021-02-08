## webmin-dhcpd-bind

ISC (https://kb.isc.org/) DNS (bind9) and DHCP servers in the same container. \
Managed under https://www.webmin.com \
Based on ubuntu:xenial-20210114 and the excellent work of:
  - sameersbn/bind
  - networkboot/dhcpd

The (unforked) main process is the webmin server.
If you want to stop the container, just stop the webmin server.

#### Usage

Start: \
  docker run ***[options]*** -v ***base_dir***:/data goulart/webmin-dhcpd-bind:1.2 [***netwkInterfaces***] [--no-dns] [--no-dhcp]

Start examples: \
  `docker run -d --rm --net host -v /etc/docker:/data:Z webmin-dhcpd-bind:1.2 eth0` \
(`eth0` is the adapter the DHCPd will bind to)

  `docker run -d --rm -p 53:53/tcp -p 53:53/udp 10000:10000/tcp -v /etc/docker:/data:Z webmin-dhcpd-bind:1.2 --no-dhcp` \
(Start bind and webmin)

[***netwkInterfaces***] (dhcp only)
  - More than one network interface may be specified for dhcpd
  - If none given, dhcpd listens on all interfaces
  - If starting dhcpd always use `--net host` (broadcasting does not bridge)

[--no-dns]  Do not start bind9 (DNS server)

[--no-dhcp] Do not start DHCP server

#### Connectivity

Webmin:
  * point browser to https://***[host]***:10000
  * username: `root`
  * password: `password`

Ports:
  * DNS server (bind9):
    * 53/udp
    * 53/tcp
  * DHCP server:
    * 67/udp
    * 68/udp
    * 67/tcp
    * 68/tcp
  * webmin:
    * 10000/tcp
