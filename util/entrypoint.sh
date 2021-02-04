#!/bin/bash

set -e

WEBMIN_DATA_DIR=${DATA_DIR}/webmin
ROOT_PASSWORD=${ROOT_PASSWORD:-password}
WEBMIN_ENABLED=${WEBMIN_ENABLED:-true}
WEBMIN_INIT_SSL_ENABLED=${WEBMIN_INIT_SSL_ENABLED:-true}
WEBMIN_INIT_REDIRECT_PORT=${WEBMIN_INIT_REDIRECT_PORT:-10000}
WEBMIN_INIT_REFERERS=${WEBMIN_INIT_REFERERS:-NONE}

BIND_DATA_DIR=${DATA_DIR}/bind
BIND_EXIT_CODE=0

DHCPD_DATA_DIR=${DATA_DIR}/dhcpd
DHCPD_PROTOCOL=${DHCPD_PROTOCOL:-4}
DHCPD_DEFAULT="$DHCPD_DATA_DIR/dhcpdDefaultEnv.sh"
DHCPD_EXIT_CODE=0

echo "Variables done..."

## ----- webmin -----
create_webmin_data_dir() {
  mkdir -p ${WEBMIN_DATA_DIR}
  chmod -R 0755 ${WEBMIN_DATA_DIR}
  chown -R root:root ${WEBMIN_DATA_DIR}

  # populate the default webmin configuration if it does not exist
  if [ ! -d ${WEBMIN_DATA_DIR}/etc ]; then
    mv /etc/webmin ${WEBMIN_DATA_DIR}/etc
  fi
  rm -rf /etc/webmin
  ln -sf ${WEBMIN_DATA_DIR}/etc /etc/webmin
  
  # Add the DHCPd config dir for webmin
  mkdir -p ${WEBMIN_DATA_DIR}/dhcpd
  chmod -R 0755 ${WEBMIN_DATA_DIR}/dhcpd
  chown -R root:root ${WEBMIN_DATA_DIR}/dhcpd
}

disable_webmin_ssl() {
  sed -i 's/ssl=1/ssl=0/g' /etc/webmin/miniserv.conf
}

set_webmin_config() {
  echo "redirect_port=$WEBMIN_INIT_REDIRECT_PORT" >> /etc/webmin/miniserv.conf
  echo "dhcpd_conf=$DHCPD_DATA_DIR/dhcpd.conf" >> /etc/webmin/dhcpd/config
  echo "lease_file=$DHCPD_DATA_DIR/dhcpd.leases" >> /etc/webmin/dhcpd/config
  echo "pid_file=$DHCPD_DATA_DIR/run/dhcpd.pid" >> /etc/webmin/dhcpd/config
  echo "start_cmd=/etc/init.d/isc-dhcp-server start" >> /etc/webmin/dhcpd/config
  echo "stop_cmd=/etc/init.d/isc-dhcp-server stop" >> /etc/webmin/dhcpd/config
  echo "restart_cmd=/etc/init.d/isc-dhcp-server restart" >> /etc/webmin/dhcpd/config
}

set_webmin_referers() {
  echo "referers=$WEBMIN_INIT_REFERERS" >> /etc/webmin/config
}

first_init() {
  if [ ! -f /data/.initialized ]; then
    set_webmin_config
    if [ "${WEBMIN_INIT_SSL_ENABLED}" == "false" ]; then
      disable_webmin_ssl
    fi
    if [ "${WEBMIN_INIT_REFERERS}" != "NONE" ]; then
      set_webmin_referers
    fi
    touch /data/.initialized
  fi
}

## ----- DNS bind -----

create_bind_data_dir() {
  mkdir -p ${BIND_DATA_DIR}

  # populate default bind configuration if it does not exist
  if [ ! -d ${BIND_DATA_DIR}/etc ]; then
    mv /etc/bind ${BIND_DATA_DIR}/etc
  fi
  rm -rf /etc/bind
  ln -sf ${BIND_DATA_DIR}/etc /etc/bind
  chmod -R 0775 ${BIND_DATA_DIR}
  chown -R ${BIND_USER}:${BIND_USER} ${BIND_DATA_DIR}

  if [ ! -d ${BIND_DATA_DIR}/lib ]; then
    mkdir -p ${BIND_DATA_DIR}/lib
    chown ${BIND_USER}:${BIND_USER} ${BIND_DATA_DIR}/lib
  fi
  rm -rf /var/lib/bind
  ln -sf ${BIND_DATA_DIR}/lib /var/lib/bind
}

set_root_passwd() {
  echo "root:$ROOT_PASSWORD" | chpasswd
}

create_pid_dir() {
  mkdir -p /var/run/named
  chmod 0775 /var/run/named
  chown root:${BIND_USER} /var/run/named
}

create_bind_cache_dir() {
  mkdir -p /var/cache/bind
  chmod 0775 /var/cache/bind
  chown root:${BIND_USER} /var/cache/bind
}

create_pid_dir
create_bind_data_dir
create_bind_cache_dir

echo "Starting named..."
"$(command -v named)" -u ${BIND_USER}
BIND_EXIT_CODE=$?

## ----- DHCPd -----

# Single argument to command line is interface name
if [ $# -eq 1 -a -n "$1" ]; then
    # skip wait-for-interface behavior if found in path
    if ! which "$1" >/dev/null; then
        # loop until interface is found, or we give up
        NEXT_WAIT_TIME=1
        until [ -e "/sys/class/net/$1" ] || [ $NEXT_WAIT_TIME -eq 4 ]; do
            sleep $(( NEXT_WAIT_TIME++ ))
            echo "Waiting for interface '$1' to become available... ${NEXT_WAIT_TIME}"
        done
        if [ -e "/sys/class/net/$1" ]; then
            IFACE="$1"
        fi
    fi
fi

# No arguments means all interfaces
if [ -z "$1" ]; then
    IFACE=" "
fi

echo "DHCPd bind interface: $IFACE"

if [ -n "$IFACE" ]; then
    # Run dhcpd for specified interface or all interfaces
	# DNS bind open on all interfaces

    # Create dirs
    mkdir -p ${DHCPD_DATA_DIR}
    mkdir -p $DHCPD_DATA_DIR/run/    

    dhcpd_conf="${DHCPD_DATA_DIR}/dhcpd.conf"
    if [ ! -f "$dhcpd_conf" ]; then
      BCAST=$(ip -4 addr show $(ls /sys/class/net/ | grep -v lo | head -n 1) | grep -Po 'brd \K[\d.]+')
      NETAD=$(echo $BCAST | grep -Po '\d+\.\d+\.\d+')
      echo "option domain-name \"dummy.lan\";" > $dhcpd_conf
      echo "option broadcast-address $BCAST;" >> $dhcpd_conf
      echo "subnet $NETAD.0 netmask 255.255.255.0 { range $NETAD.10 $NETAD.100; }" >> $dhcpd_conf
      echo "host dummy { };" >> $dhcpd_conf
    fi
    
    if [ ! -r "$dhcpd_conf" ]; then
        echo "Please ensure '$dhcpd_conf' exists and is readable."
        echo "Run the container with arguments 'man dhcpd.conf' if you need help with creating the configuration."
        exit 1
    fi

    uid=$(stat -c%u "$DHCPD_DATA_DIR")
    gid=$(stat -c%g "$DHCPD_DATA_DIR")
    if [ $gid -ne 0 ]; then
        groupmod -g $gid dhcpd
    fi
    if [ $uid -ne 0 ]; then
        usermod -u $uid dhcpd
    fi

    [ -e "$DHCPD_DATA_DIR/dhcpd.leases" ] || touch "$DHCPD_DATA_DIR/dhcpd.leases"
    chown dhcpd:dhcpd "$DHCPD_DATA_DIR/dhcpd.leases"
    if [ -e "$DHCPD_DATA_DIR/dhcpd.leases~" ]; then
        chown dhcpd:dhcpd "$DHCPD_DATA_DIR/dhcpd.leases~"
    fi

    container_id=$(grep docker /proc/self/cgroup | sort -n | head -n 1 | cut -d: -f3 | cut -d/ -f3)
    if perl -e '($id,$name)=@ARGV;$short=substr $id,0,length $name;exit 1 if $name ne $short;exit 0' $container_id $HOSTNAME; then
        echo "You must add the 'docker run' option '--net=host' if you want to provide DHCP service to the host network."
    fi

    echo "OPTIONS=-$DHCPD_PROTOCOL" > $DHCPD_DEFAULT
    echo "DHCPD_PID=$DHCPD_DATA_DIR/run/dhcpd.pid" >> $DHCPD_DEFAULT
    echo "DHCPD_CONF=$DHCPD_DATA_DIR/dhcpd.conf"  >> $DHCPD_DEFAULT
    echo "DHCPD_LEASES=$DHCPD_DATA_DIR/dhcpd.leases" >> $DHCPD_DEFAULT
    echo "INTERFACES=$IFACE" >> $DHCPD_DEFAULT
    chmod 755 $DHCPD_DEFAULT
    /etc/init.d/isc-dhcp-server start
    # nohup /usr/sbin/dhcpd -$DHCPD_PROTOCOL -d -pf "$DHCPD_DATA_DIR/run/dhcpd.pid" -cf "$DHCPD_DATA_DIR/dhcpd.conf" -lf "$DHCPD_DATA_DIR/dhcpd.leases" $IFACE > "$DHCPD_DATA_DIR/dhcpdLastRun.log" &
	DHCPD_EXIT_CODE=$?
fi

## ----- Check exit codes and start webmin -----

if [ $BIND_EXIT_CODE -ne 0 ]; then
  echo "Failed to start DNS (bind). Exit code $BIND_EXIT_CODE"
  exit 1
elif [ $DHCPD_EXIT_CODE -ne 0 ]; then
  echo "Failed to start DHCPd. Exit code $DHCPD_EXIT_CODE"
  exit 1
else
  if [ "${WEBMIN_ENABLED}" == "true" ]; then
    create_webmin_data_dir
    first_init
    set_root_passwd
    echo "Starting webmin..."
    exec /etc/webmin/start
  else
    sleep infinity
  fi
fi
