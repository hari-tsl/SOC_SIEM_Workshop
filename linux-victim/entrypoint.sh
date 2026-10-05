#!/bin/bash
set -euo pipefail
: "${LAB_PASSWORD:?LAB_PASSWORD required}"
echo "student:$LAB_PASSWORD" | chpasswd
ssh-keygen -A
mkdir -p /run/sshd /var/log/nginx /var/log/supervisor
touch /var/log/auth.log /var/log/syslog /var/log/vsftpd.log
exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/lab.conf
