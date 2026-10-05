#!/bin/bash
set -euo pipefail
: "${LAB_PASSWORD:?LAB_PASSWORD required}"
echo "student:$LAB_PASSWORD" | chpasswd
ssh-keygen -A

mkdir -p /run/sshd /run/php /var/log/nginx /var/log/supervisor /var/run/mysqld
chown -R mysql:mysql /var/run/mysqld /var/lib/mysql
chown -R www-data:www-data /var/www/html /run/php
touch /var/log/auth.log /var/log/syslog /var/log/vsftpd.log
chown syslog:adm /var/log/auth.log /var/log/syslog /var/log/vsftpd.log || true

# Initialize MariaDB data directory if not already populated
if [ ! -d "/var/lib/mysql/mysql" ]; then
    mysql_install_db --user=mysql --ldata=/var/lib/mysql >/dev/null 2>&1
fi

# Temporarily spin up MariaDB to seed DVWA database and tables
/usr/bin/mysqld_safe --skip-syslog >/dev/null 2>&1 &
MYSQL_PID=$!

for _ in {1..30}; do
    if mysqladmin ping --silent 2>/dev/null; then break; fi
    sleep 1
done

# Initialize DVWA database and grant user privileges
mariadb -e "CREATE DATABASE IF NOT EXISTS dvwa; GRANT ALL ON dvwa.* TO 'dvwa'@'localhost' IDENTIFIED BY 'dvwa'; FLUSH PRIVILEGES;"

# Seed default DVWA tables and accounts
mariadb dvwa << 'EOSQL'
CREATE TABLE IF NOT EXISTS users (
  user_id int(6) NOT NULL AUTO_INCREMENT,
  first_name varchar(15) DEFAULT NULL,
  last_name varchar(15) DEFAULT NULL,
  user varchar(15) DEFAULT NULL,
  password varchar(32) DEFAULT NULL,
  avatar varchar(70) DEFAULT NULL,
  last_login timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  failed_login int(3) DEFAULT 0,
  PRIMARY KEY (user_id)
);
INSERT INTO users (user_id, first_name, last_name, user, password, avatar, failed_login)
VALUES 
(1,'admin','admin','admin',MD5('password'),'/dvwa/images/admin.jpg',0),
(2,'Gordon','Brown','gordonb',MD5('abc123'),'/dvwa/images/gordonb.jpg',0),
(3,'Hack','Me','1337',MD5('8934e7d15453e97507ef794cf7b0519d'),'/dvwa/images/1337.jpg',0),
(4,'Pablo','Picasso','pablo',MD5('letmein'),'/dvwa/images/pablo.jpg',0),
(5,'Bob','Smith','smithy',MD5('password'),'/dvwa/images/smithy.jpg',0)
ON DUPLICATE KEY UPDATE user=VALUES(user);

CREATE TABLE IF NOT EXISTS guestbook (
  comment_id smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  comment varchar(300) DEFAULT NULL,
  name varchar(100) DEFAULT NULL,
  PRIMARY KEY (comment_id)
);
INSERT INTO guestbook (comment_id, comment, name)
VALUES (1,'This is a test comment.','test')
ON DUPLICATE KEY UPDATE name=VALUES(name);
EOSQL

# Stop temporary database process so supervisord can manage it
mysqladmin shutdown >/dev/null 2>&1 || kill $MYSQL_PID 2>/dev/null || true
wait $MYSQL_PID 2>/dev/null || true
sleep 1

exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/lab.conf
