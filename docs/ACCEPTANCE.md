# Delivery-host acceptance

Local static validation is not live acceptance. Record the host type, CPU architecture, RAM, disk, Docker/Compose versions, KVM availability, run time and image manifest before sign-off.

1. From a clean supported host, run `sudo ./start.sh`. Confirm exit status 0 and the final READY message.
2. Open the dashboard. Confirm every panel renders without a missing-field or missing-object error. Check the three saved Discover searches.
3. Save `./scripts/acceptance.sh` output. It runs new scenarios and asserts **new events since that run began**, preventing old indices from creating a false pass.
4. Confirm failure and success events for Linux SSH and Windows student logons, native Windows OpenSSH logs, Linux and Windows FTP records, web requests and Kali activity.
5. Inspect Windows 4688, PowerShell Operational and share auditing manually. Automatic acceptance does not yet require every configured audit category.
6. From Kali, confirm lab targets resolve. Confirm a direct Internet request times out; no arbitrary external scenario is provided. Check host listeners: only localhost 5601,8080,8006 should be published by this project.
7. Stop/start and then reboot the Linux host. Confirm retained Windows installation, ELK data, running Windows services and another successful acceptance run.
8. On a disposable installation only, verify reset confirmation cancels on anything except DELETE. Confirm the accepted destructive reset removes volumes, and the next start reprovisions the lab.
9. Capture image metadata using `./scripts/capture-images.sh` and preserve the output with handoff evidence.

Do not label Windows guest provisioning, dashboard rendering, container networking, service logging or reboot persistence as verified solely because local tests passed.
