---
title: "Sample Document with ASCII Diagram"
author: "CI Bot"
date: "2026-07-17"
---

# Introduction

This document tests the Markdown-to-PDF pipeline, including:

- Complex ASCII diagrams
- Tables with many columns
- Code blocks
- Citations (via `references.bib`)

---

## SecOps SIEM Integration

Below is the complete architecture diagram for the SIEM integration flow.

```ascii
3.1 SecOps SIEM Integration
AKS Control Plane
  ├── kube-apiserver
  ├── kube-audit-admin
  └── guard
        │
        ▼
AKS Diagnostic Settings
        │
        ▼
Log Analytics Workspace ───────────────┐
                                       │
Defender for Containers                │
(managed security alerts) ─────────────┤
                                       │
Tetragon Platform Component            │
(selected runtime telemetry)           │
        │                              │
        └──► Log Analytics Workspace ──┤
                                       ▼
                              Microsoft Sentinel
                                       │
                                       ├── Analytic Rules
                                       ├── Security Alerts
                                       ├── Incidents
                                       └── Automation
                                              │
                                              ▼
                                   copilot-global-triage
                                              │
                                              ▼
                                    Platform Rule Review
                                     Logic App Playbook
```

This diagram shows the end‑to‑end flow from AKS control plane logs to Sentinel alerting and automated triage.

---

## Data Flow Details

| Step | Component | Action |
|------|-----------|--------|
| 1    | AKS Control Plane | Emits audit logs and guard events |
| 2    | Diagnostic Settings | Streams logs to Log Analytics Workspace |
| 3    | Defender for Containers | Generates security alerts |
| 4    | Tetragon | Captures runtime telemetry |
| 5    | Log Analytics | Aggregates all data |
| 6    | Microsoft Sentinel | Runs analytics and creates incidents |
| 7    | Automation | Triggers playbooks for response |

---

## Code Block Example

```python
def process_siem_event(event):
    if event['severity'] >= 4:
        sentinel.create_incident(event)
        triage.playbook(event)
    return "processed"
```

---

## Citations

This architecture is based on best practices from cloud-native SIEM [@cloudsiem2024]. Log aggregation patterns are discussed in [@logaggregation2023].

---

## Conclusion

The integrated SIEM pipeline provides:

- Real‑time threat detection
- Automated incident response
- Centralised logging across all clusters

With this setup, the platform achieves a PBMM‑ready security posture.
