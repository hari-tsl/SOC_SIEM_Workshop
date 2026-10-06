#!/bin/bash
set -uo pipefail

: "${LAB_PASSWORD:=SocLabPass123!}"
echo "student:$LAB_PASSWORD" | chpasswd || true
ssh-keygen -A 2>/dev/null || true

mkdir -p /run/sshd /run/php /var/log/nginx /var/log/supervisor /var/run/mysqld /var/run/vsftpd/empty
chown -R mysql:mysql /var/run/mysqld /var/lib/mysql 2>/dev/null || true
chown -R www-data:www-data /var/www/html /run/php 2>/dev/null || true
touch /var/log/auth.log /var/log/syslog /var/log/vsftpd.log 2>/dev/null || true
chmod 666 /var/log/auth.log /var/log/syslog /var/log/vsftpd.log 2>/dev/null || true

# Initialize database in background once supervisord starts MariaDB
(
    for _ in {1..30}; do
        if mariadb -e "SELECT 1" >/dev/null 2>&1; then break; fi
        sleep 2
    done
    mariadb -e "CREATE DATABASE IF NOT EXISTS dvwa; GRANT ALL ON dvwa.* TO 'dvwa'@'localhost' IDENTIFIED BY 'dvwa'; FLUSH PRIVILEGES;" 2>/dev/null || true
    mariadb dvwa << 'EOSQL' 2>/dev/null || true
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
) &

exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/lab.conf
