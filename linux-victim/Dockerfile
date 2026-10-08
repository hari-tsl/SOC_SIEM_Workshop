FROM debian:12-slim
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    rsyslog \
    nginx \
    vsftpd \
    python3 \
    supervisor \
    curl \
    procps \
    logrotate \
    cron \
    ca-certificates \
    git \
    mariadb-server \
    php8.2-fpm \
    php8.2-mysql \
    php8.2-gd \
    php8.2-curl \
    php8.2-sqlite3 \
    sqlite3 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -s /bin/bash student \
    && mkdir -p /run/sshd /srv/web /var/run/vsftpd/empty /run/php /var/www/html /var/log/nginx

# Clone DVWA vulnerable web application
RUN git clone --depth 1 https://github.com/digininja/DVWA.git /var/www/html/dvwa \
    && chown -R www-data:www-data /var/www/html/dvwa \
    && chmod -R 777 /var/www/html/dvwa/hackable/uploads

# Configure PHP settings for DVWA
RUN sed -i 's/allow_url_include = Off/allow_url_include = On/g' /etc/php/8.2/fpm/php.ini && \
    sed -i 's/allow_url_fopen = Off/allow_url_fopen = On/g' /etc/php/8.2/fpm/php.ini

# Landing redirect for root /
RUN echo "<?php header('Location: /dvwa/login.php'); exit; ?>" > /var/www/html/index.php

COPY dvwa-config.inc.php /var/www/html/dvwa/config/config.inc.php
COPY webapp/app.py /srv/web/app.py
COPY nginx.conf /etc/nginx/sites-enabled/default
COPY rsyslog.conf /etc/rsyslog.conf
COPY vsftpd.conf /etc/vsftpd.conf
COPY supervisord.conf /etc/supervisor/conf.d/lab.conf
COPY logrotate.conf /etc/logrotate.d/lab
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh && printf 'PasswordAuthentication yes\nPermitRootLogin no\nUsePAM yes\n' > /etc/ssh/sshd_config.d/00-lab.conf
EXPOSE 80 22 21
ENTRYPOINT ["/entrypoint.sh"]
