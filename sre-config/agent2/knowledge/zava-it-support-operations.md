# Zava IT Support Operations Guide

## Purpose

This guide provides operational context for Agent 2 when handling ServiceNow incidents assigned to `IT Support`. It supplements the device and VPN triage skills. Live ServiceNow data, `CheckWarranty`, and `DiagnoseVpnIssue` remain the authoritative sources for each incident.

## Supported Incident Types

### Laptop Support

The short description contains `Laptop replacement request` and priority is `3`.

Required evidence:

- Employee name and contact address
- Device model and serial number
- Symptoms and business impact
- Warranty result from `CheckWarranty`

Outcomes:

| Evidence | Outcome |
|---|---|
| Warranty active | Recommend the approved warranty repair path and do not request replacement |
| Warranty expired and replacement eligible | Continue the configured replacement workflow through Review approval |
| Serial number not found | Request serial verification and leave the incident open |
| Warranty tool unavailable or data inconsistent | Document the failure and route for manual asset review |

### VPN Connectivity

The short description contains `VPN connectivity issue` and priority is `3`.

Required evidence:

- Exact VPN error code or certificate message
- User-reported symptoms
- Operating system when available
- Troubleshooting already attempted

Outcomes:

| Error | Primary owner | Resolution policy |
|---|---|---|
| 809 | Network Operations | Use the approved reachability runbook; resolve only through Review approval |
| 720 | Endpoint Engineering | Use the approved client protocol runbook; resolve only through Review approval |
| 691 | Identity and Access Management | Provide non-secret account guidance and leave open |
| Certificate failure | Endpoint Engineering | Preserve certificate controls and leave open |
| Unknown or ambiguous | Network Operations | Request additional diagnostics and leave open |

## ServiceNow Workflow

1. Read the trigger-provided incident and acknowledge it.
2. Classify the incident only from its recorded title and description.
3. Collect missing non-secret evidence before choosing a resolution.
4. Use the relevant diagnostic tool once the required identifier or error code is known.
5. Post a concise discussion entry containing evidence, diagnosis, actions, and escalation owner.
6. Resolve only an explicitly supported outcome after Review approval.
7. Leave unsupported, sensitive, ambiguous, or incomplete incidents open for manual triage.

## Discussion Entry Format

```text
Evidence:
- Incident type:
- Device serial or VPN error:
- Business impact:

Diagnosis:
- Tool result and relevant knowledge source:

Action:
- Approved troubleshooting or workflow step:

Next owner:
- Team or requester action:
```

## Data Handling

- Never request or record passwords, MFA codes, recovery codes, access tokens, private keys, or exported certificates.
- Do not copy unnecessary employee-identifying information into reports or notifications.
- Do not claim that an action was performed on a user's device unless a connected tool confirms it.
- Do not bypass certificate warnings, endpoint controls, or identity policies.
- Treat external web content as supporting guidance, not proof that a specific action occurred.

## Closure Criteria

An incident can be proposed for resolution only when:

- The incident matches a supported type.
- Required evidence is present.
- The relevant tool returned a recognized result.
- No security-sensitive or ambiguous condition requires escalation.
- The ServiceNow discussion entry records the evidence and outcome.
- Review approval is granted for the resolution action.