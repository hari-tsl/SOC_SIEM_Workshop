#!/bin/bash
set -uo pipefail

: "${LAB_PASSWORD:=SocLabPass123!}"
echo "student:$LAB_PASSWORD" | chpasswd || true
ssh-keygen -A 2>/dev/null || true

mkdir -p /run/sshd /run/php /var/log/nginx /var/log/supervisor /run/mysqld /var/run/mysqld /var/run/vsftpd/empty
chmod 777 /run/mysqld /var/run/mysqld 2>/dev/null || true
if [ ! -d /var/lib/mysql/mysql ]; then
    mariadb-install-db --user=mysql --datadir=/var/lib/mysql >/dev/null 2>&1 || true
fi
chown -R mysql:mysql /run/mysqld /var/run/mysqld /var/lib/mysql 2>/dev/null || true
chown -R www-data:www-data /var/www/html /run/php /var/log/nginx 2>/dev/null || true
touch /var/log/auth.log /var/log/syslog /var/log/vsftpd.log /var/log/nginx/access.json /var/log/nginx/error.log 2>/dev/null || true
chmod 666 /var/log/auth.log /var/log/syslog /var/log/vsftpd.log /var/log/nginx/access.json /var/log/nginx/error.log 2>/dev/null || true

# Synchronously initialize MariaDB database, users, and tables before starting services
/usr/sbin/mariadbd --user=mysql --skip-networking --socket=/run/mysqld/mysqld.sock &
TMP_PID=$!
for _ in {1..30}; do
    if mariadb --socket=/run/mysqld/mysqld.sock -e "SELECT 1" >/dev/null 2>&1; then break; fi
    sleep 1
done

mariadb --socket=/run/mysqld/mysqld.sock -e "
CREATE DATABASE IF NOT EXISTS dvwa;
CREATE USER IF NOT EXISTS 'dvwa'@'localhost' IDENTIFIED BY 'dvwa';
CREATE USER IF NOT EXISTS 'dvwa'@'127.0.0.1' IDENTIFIED BY 'dvwa';
CREATE USER IF NOT EXISTS 'dvwa'@'%' IDENTIFIED BY 'dvwa';
ALTER USER 'dvwa'@'localhost' IDENTIFIED BY 'dvwa';
ALTER USER 'dvwa'@'127.0.0.1' IDENTIFIED BY 'dvwa';
ALTER USER 'dvwa'@'%' IDENTIFIED BY 'dvwa';
GRANT ALL PRIVILEGES ON dvwa.* TO 'dvwa'@'localhost';
GRANT ALL PRIVILEGES ON dvwa.* TO 'dvwa'@'127.0.0.1';
GRANT ALL PRIVILEGES ON dvwa.* TO 'dvwa'@'%';
FLUSH PRIVILEGES;" 2>/dev/null || true

mariadb --socket=/run/mysqld/mysqld.sock dvwa << 'EOSQL' 2>/dev/null || true
CREATE TABLE IF NOT EXISTS users (
  user_id int(6) NOT NULL AUTO_INCREMENT,
  first_name varchar(15) DEFAULT NULL,
  last_name varchar(15) DEFAULT NULL,
  user varchar(15) DEFAULT NULL,
  password varchar(32) DEFAULT NULL,
  avatar varchar(70) DEFAULT NULL,
  last_login timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  failed_login int(3) DEFAULT 0,
  role varchar(20) DEFAULT 'user',
  account_enabled tinyint(1) DEFAULT 1,
  PRIMARY KEY (user_id)
);
INSERT INTO users (user_id, first_name, last_name, user, password, avatar, failed_login, role, account_enabled)
VALUES 
(1,'admin','admin','admin',MD5('password'),'/dvwa/images/admin.jpg',0,'admin',1),
(2,'Gordon','Brown','gordonb',MD5('abc123'),'/dvwa/images/gordonb.jpg',0,'user',1),
(3,'Hack','Me','1337',MD5('8934e7d15453e97507ef794cf7b0519d'),'/dvwa/images/1337.jpg',0,'user',1),
(4,'Pablo','Picasso','pablo',MD5('letmein'),'/dvwa/images/pablo.jpg',0,'user',1),
(5,'Bob','Smith','smithy',MD5('password'),'/dvwa/images/smithy.jpg',0,'user',1)
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

CREATE TABLE IF NOT EXISTS access_log (
  id int AUTO_INCREMENT PRIMARY KEY,
  user_id int NOT NULL,
  target_id int NOT NULL,
  action varchar(50) NOT NULL,
  timestamp datetime NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS security_log (
  id int AUTO_INCREMENT PRIMARY KEY,
  user_id int NOT NULL,
  target_id int NOT NULL,
  action varchar(50) NOT NULL,
  timestamp datetime NOT NULL,
  ip_address varchar(45) NOT NULL
) ENGINE=InnoDB;
EOSQL

kill -TERM "$TMP_PID" 2>/dev/null || true
wait "$TMP_PID" 2>/dev/null || true
rm -f /run/mysqld/mysqld.sock /run/mysqld/mysqld.pid 2>/dev/null || true

exec /usr/bin/supervisord -n -c /etc/supervisor/conf.d/lab.conf
