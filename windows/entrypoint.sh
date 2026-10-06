#!/bin/bash
set -euo pipefail

: "${LAB_PASSWORD:?LAB_PASSWORD required}"

# Create student user if not exists
if ! id student >/dev/null 2>&1; then
    useradd -m -s /bin/bash student
fi
echo "student:$LAB_PASSWORD" | chpasswd

# Setup Samba student account
(echo "$LAB_PASSWORD"; echo "$LAB_PASSWORD") | smbpasswd -a -s student

# Prepare directories and share file
mkdir -p /storage/LabShare /var/log/samba /var/log/windows-ftp /var/log/winlogbeat /var/log/supervisor /run/sshd /var/run/vsftpd/empty
echo "Synthetic training document. No production data." > /storage/LabShare/training.txt
chown -R student:student /storage/LabShare
chmod 755 /storage/LabShare

touch /var/log/auth.log /var/log/vsftpd.log /var/log/windows-ftp/ftpsvc.log /var/log/winlogbeat/windows-events.json
ssh-keygen -A

exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/windows.conf
