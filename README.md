## webmin-dhcpd-bind

### **WARNING** - very rough - needs refinement and testing
#### Considered work in progress

ISC (https://kb.isc.org/) DNS (bind9) and DHCP servers in the same container. \
Managed under https://www.webmin.com \
Based on ubuntu:xenial-20210114 and the excellent work of:
  - sameersbn/bind
  - networkboot/dhcpd

Start: \
  docker run ***[options]*** --net host -v ***base_dir***:/data goulart/webmin-dhcpd-bind:1.0 ***netwkInterface***

Start example: \
  `docker run -d --rm --net host -v /etc/docker:/data:Z webmin-dhcpd-bind:latest eth0` \
(`eth0` is the adapter the DHCPd will bind to)

Webmin:
  * point browser to https://***[host]***:10000
  * username: `root`
  * password: `password`

Ports:
  * DNS (bind9):
    * 53/udp
    * 53/tcp
  * DHCPd:
    * 67/udp
    * 68/udp
    * 67/tcp
    * 68/tcp
  * webmin:
    * 10000/tcp
