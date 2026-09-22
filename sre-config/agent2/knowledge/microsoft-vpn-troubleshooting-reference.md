# Microsoft VPN Troubleshooting Reference

Source: [Troubleshoot Always On VPN](https://learn.microsoft.com/troubleshoot/windows-server/networking/troubleshoot-always-on-vpn), Microsoft Learn.

This reference summarizes evidence and escalation guidance relevant to Zava VPN incidents. The Microsoft source and `DiagnoseVpnIssue` provide technical context; the Zava IT Support Operations Guide defines ServiceNow ownership and closure policy.

## Initial Evidence

Collect these non-secret details before choosing a runbook:

- Exact VPN or certificate error code
- Operating system and VPN client version
- Time of the failed connection
- Whether normal internet access works
- Whether the failure occurs on another trusted network
- Relevant `RasClient` event code and timestamp when available

Do not collect passwords, MFA codes, tokens, private keys, exported certificates, or full diagnostic logs containing unnecessary personal data.

## Error 809

Microsoft describes error 809 as a failure to establish a connection because the VPN server does not respond. Network devices between the client and server, including firewalls, routers, and NAT devices, may be involved.

Useful evidence:

- Whether the VPN server name resolves in DNS
- Whether the problem changes on another trusted network
- Whether UDP ports 500 and 4500 are permitted through the managed network path
- Whether other users are affected

Zava handling:

- Give the approved low-risk client checks returned by `DiagnoseVpnIssue`.
- Do not instruct users to change corporate firewall or router policy.
- Escalate persistent or widespread failures to Network Operations.

## Authentication Policy Failures

Microsoft documents authentication failures when client and Network Policy Server requirements do not match. Error 812 is one example and can be associated with RRAS event 20276.

Zava handling:

- Record the exact error and event timestamp.
- Do not request credentials or weaken authentication requirements.
- Route account failures to Identity and Access Management.
- Route NPS, RADIUS, or protocol-policy mismatches to Network Operations.

## Certificate Failures

Microsoft documents certificate-related failures including missing machine certificates, expired certificates, missing Server Authentication usage, untrusted roots, and VPN server names that do not match certificate subjects.

Zava handling:

- Confirm device date, time, and time zone.
- Record only certificate subject, issuer, and expiry when needed.
- Never export private keys or bypass certificate warnings.
- Escalate managed certificate and device compliance work to Endpoint Engineering.

## Diagnostic Logs

Microsoft recommends client application logs, especially `RasClient` events, for connection errors. NPS accounting and event logs can provide server-side policy evidence.

For ServiceNow, post only the minimum useful evidence:

- Error or event code
- Timestamp
- VPN client and operating system version
- A short symptom summary
- Escalation owner

Attach full logs only through an approved secure support process.

## Resolution Boundary

Knowledge retrieval does not prove that remediation occurred. Agent 2 may propose resolution only when the incident matches a supported Zava workflow, the diagnostic result is recognized and low risk, required evidence is present, and Review approval is granted.