---
metadata:
  api_version: azuresre.ai/v2
  kind: Skill
name: vpn-connectivity-triage
description: Triage ServiceNow VPN connectivity incidents using approved error-code runbooks. Use for VPN errors 809, 720, 691, certificate failures, and unknown VPN connection errors.
tools:
  - GetServiceNowIncident
  - AcknowledgeServiceNowIncident
  - DiagnoseVpnIssue
  - PostServiceNowDiscussionEntry
  - ResolveServiceNowIncident
---

# VPN Connectivity Triage

## Purpose
Apply a bounded VPN runbook without claiming access to the user's device or collecting authentication secrets.

## Required Evidence
- VPN error code or certificate error
- User-reported symptoms
- Device operating system, when available
- Troubleshooting already attempted

## Workflow
1. Read and acknowledge the incident using its trigger-provided ServiceNow identifier.
2. Extract the error code exactly as reported. Do not infer a code from generic symptoms.
3. Call `DiagnoseVpnIssue` with the error code, symptoms, and operating system.
4. Post the returned diagnosis and numbered remediation steps to ServiceNow.
5. Choose one outcome:
   - `safe_to_resolve` is true: propose resolution through the Review approval gate and state that the user can reopen the incident if the issue persists.
   - `safe_to_resolve` is false: post the returned escalation team and leave the incident open.
   - Error not recognized: route to Network Operations and leave the incident open.

## Guardrails
- Never request, store, or repeat passwords, MFA codes, recovery codes, tokens, or private keys.
- Never instruct the user to bypass certificate warnings or security controls.
- Never claim that a remediation was performed on the user's device.
- Never resolve authentication, certificate, unknown, or ambiguous failures automatically.