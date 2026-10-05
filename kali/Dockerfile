FROM kalilinux/kali-rolling:latest
RUN apt-get update && apt-get install -y --no-install-recommends nmap curl openssh-client sshpass smbclient python3 ca-certificates && rm -rf /var/lib/apt/lists/*
COPY scenarios.py /opt/scenarios.py
RUN mkdir /logs
CMD ["sleep", "infinity"]
