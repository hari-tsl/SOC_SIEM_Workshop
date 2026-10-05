FROM debian:12-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends openssh-server rsyslog nginx vsftpd python3 supervisor curl procps logrotate cron ca-certificates && rm -rf /var/lib/apt/lists/*  && useradd -m -s /bin/bash student && mkdir -p /run/sshd /srv/web /var/run/vsftpd/empty
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
