# Validation record

Validated locally on 2026-10-05:

- Python source parses successfully.
- Every shell script passes `bash -n`.
- YAML configuration parses; referenced bind-mount files exist.
- Published ports use loopback bindings; Kali and Linux attach only to the internal lab network.
- All 15 Kibana saved objects parse, have unique IDs and resolve their references.
- Six tests pass: actual HTTP target with the intentional SQL injection, idempotent private credential generation, rejection of executable shell syntax in environment values, fresh-time filtering of every acceptance query, passing complete telemetry and rejecting missing telemetry.

Not executed in this workspace (Docker, KVM and PowerShell runtimes unavailable):

- Docker image builds or Compose engine validation.
- Windows installation, OEM task execution and PowerShell parser checks.
- Logstash/Beats runtime configuration validation and ingestion.
- Live Kibana import/rendering.
- Full end-to-end acceptance, reboot persistence and reset/reinstallation.

The included CI workflow adds Compose rendering, PowerShell parsing and Linux/Kali image build checks when run on GitHub. It has not been run as part of this local validation. The full delivery-host acceptance checklist remains mandatory before claiming deployment success.
