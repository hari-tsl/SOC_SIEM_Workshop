FROM kalilinux/kali-rolling:latest
RUN apt-get update && apt-get install -y --no-install-recommends \
    nmap \
    curl \
    openssh-client \
    sshpass \
    smbclient \
    hydra \
    medusa \
    python3 \
    python3-requests \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY scenarios.py /opt/scenarios.py
COPY attack-menu.sh /usr/local/bin/attack
RUN chmod +x /usr/local/bin/attack && mkdir -p /logs && chmod 777 /logs
CMD ["sleep", "infinity"]
