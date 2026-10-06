FROM debian:12-slim
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    samba \
    openssh-server \
    rsyslog \
    vsftpd \
    python3 \
    supervisor \
    curl \
    procps \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Filebeat 8.19.4 to ship Windows telemetry directly to Logstash
RUN curl -fsSL https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-8.19.4-amd64.deb -o /tmp/filebeat.deb \
    && dpkg -i /tmp/filebeat.deb \
    && rm /tmp/filebeat.deb

COPY smb.conf /etc/samba/smb.conf
COPY vsftpd.conf /etc/vsftpd.conf
COPY supervisord.conf /etc/supervisor/conf.d/windows.conf
COPY filebeat.yml /etc/filebeat/filebeat.yml
COPY telemetry_server.py /opt/telemetry_server.py
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh /opt/telemetry_server.py && \
    printf 'PasswordAuthentication yes\nPermitRootLogin no\nUsePAM yes\n' > /etc/ssh/sshd_config.d/00-lab.conf

EXPOSE 21 22 445 8006 18080
ENTRYPOINT ["/entrypoint.sh"]
