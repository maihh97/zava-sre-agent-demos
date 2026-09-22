---
metadata:
  api_version: azuresre.ai/v2
  kind: Skill
name: device-support-triage
description: Triage ServiceNow laptop hardware and replacement incidents using warranty evidence. Use for device failures, repair-versus-replacement decisions, unknown serial numbers, and replacement eligibility.
tools:
  - GetServiceNowIncident
  - AcknowledgeServiceNowIncident
  - CheckWarranty
  - PostServiceNowDiscussionEntry
  - ResolveServiceNowIncident
---

# Device Support Triage

## Purpose
Determine whether a reported laptop issue should follow warranty repair, replacement, or manual asset verification. Keep every conclusion grounded in the incident and `CheckWarranty` output.

## Required Evidence
- Employee name and contact information
- Device model and serial number
- Symptoms and business impact
- Warranty status and expiry date
- Replacement eligibility and recommended model, when returned

If the serial number or symptoms are missing, ask for the missing information in a ServiceNow discussion entry and leave the incident open.

## Workflow
1. Read and acknowledge the incident using its trigger-provided ServiceNow identifier.
2. Extract the device serial number exactly as written; never guess or normalize an ambiguous serial number.
3. Call `CheckWarranty` once with that serial number.
4. Choose one evidence-based outcome:
   - Active warranty: recommend the approved warranty repair path; do not request replacement.
   - Expired and replacement eligible: continue the configured replacement workflow.
   - Device not found: request serial-number verification and leave the incident open.
   - Tool failure or inconsistent data: document the failure and route for manual asset review.
5. Post the warranty evidence and chosen outcome to ServiceNow.
6. Resolve only when the configured workflow has completed and Review approval has been granted.

## Guardrails
- Do not invent asset, employee, warranty, request, or replacement details.
- Do not treat device age alone as replacement eligibility.
- Do not expose personal data outside the incident or approved notification destination.
- Do not resolve tickets waiting for corrected serial numbers, manual review, or approval.