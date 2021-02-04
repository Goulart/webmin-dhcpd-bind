#!/bin/sh
echo Starting Webmin server in /usr/share/webmin
trap '' 1
LANG=
export LANG
#PERLIO=:raw
unset PERLIO
export PERLIO
PERLLIB=/usr/share/webmin
export PERLLIB
exec '/usr/share/webmin/miniserv.pl' --nofork $* /etc/webmin/miniserv.conf