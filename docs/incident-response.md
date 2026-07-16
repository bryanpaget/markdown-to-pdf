---
title: Aurora Container Breach Incident Response Plan
classification: UNCLASSIFIED
control: IR-4
owner: Security Operations (SecOps)
last_updated: 2026-07-13
status: Draft
review_cycle: Quarterly or after major security incidents
document_type: Incident Response Plan
---

GC Cloud One Aurora

# Container Breach Incident Response Plan

\newpage

GC Cloud One Aurora

# Container Breach Incident Response Plan

## 1. Purpose

This document outlines the Incident Response Plan for container breaches in Aurora AKS clusters. It provides SecOps with step-by-step procedures to detect, contain, eradicate, and recover from container-related security incidents, aligned with control layers (Prevent/Detect/Respond) and evidence pipelines (Azure Monitor → Sentinel).

## 2. Scope

- In-Scope: All Aurora AKS clusters (Dev/NonProd/Prod/Management).
- Out-of-Scope: Non-containerized workloads or non-AKS systems.

## 3. Incident Response Roles and Responsibilities

| Role                     | Responsibilities                                                                 |
| ------------------------ | -------------------------------------------------------------------------------- |
| Incident Commander       | Coordinates the response, ensures communication, and makes high-level decisions. |
| SecOps Analyst           | Investigates the breach, collects evidence, and implements containment measures. |
| Kubernetes Administrator | Assists with cluster-level actions (e.g., isolating pods, nodes, or namespaces). |
| Application Owner        | Provides context about the affected application and assists with recovery.       |
| Communications Lead      | Manages internal and external communications (if applicable).                    |

*During an incident, the Incident Response Team is the cross-functional group formed from the above roles (SecOps Analyst, Kubernetes Administrator, Application Owner, and Communications Lead) as needed.*

\newpage

## 4. Incident Response Playbooks

> Guidance on optional steps
> All containment and eradication steps in this section are recommendations. Based on incident severity and the Incident Commander’s approval, some actions may be omitted or adjusted.

### 4.1 Container Vulnerability (SSC-Owned)

Scenario: A vulnerability is discovered in a container image owned and maintained by SSC.

Detection:

- Trivy (CI/CD): Scan fails with CRITICAL/HIGH vulnerabilities, blocking the deployment.
- Trivy-Operator (runtime): Reports vulnerabilities on running pods via `VulnerabilityReport` objects.
- Azure Defender for Containers: Alerts on vulnerable images in the cluster.

Impact: Potential exploitation to gain unauthorized access or escalate privileges.

Control Layer: Prevent/Detect (CI/CD + Runtime)

Response Procedure:

1. Containment:
   - Block deployment in CI/CD (Trivy exit code 1) – already enforced.
   - (Optional) Isolate the affected pod if immediate risk justifies it:
     ```bash
     kubectl delete pod <pod-name> -n <namespace>
     ```

2. Eradication:
   - Identify all instances of the vulnerable image (runtime scans help here):
     ```bash
     kubectl get pods --all-namespaces -o jsonpath='{.items[*].spec.containers[*].image}' | grep <vulnerable-image>
     ```
   - Remove or update all affected pods/deployments.

3. Recovery:
   - Patch the vulnerability in the base image or application.
   - Rescan the image with Trivy (CI/CD and optionally Trivy-Operator) to confirm the fix.
   - Redeploy the patched image.

4. Post-Incident:
   - Update the [Aurora AKS Risk Assessment][ra-3-link] with new findings.
   - Review and adjust image scanning policies.

### 4.2 Container Vulnerability (Client-Owned)

Scenario: A vulnerability is discovered in a container image owned by a client team.

Detection:
- Trivy (CI/CD): Scan fails with CRITICAL/HIGH vulnerabilities.
- Trivy-Operator (runtime): Reports vulnerabilities on running client pods.
- Azure Defender for Containers: Alerts on vulnerable images.

Impact: Potential exploitation in client workloads.

Control Layer: Prevent/Detect (CI/CD + Runtime)

Response Procedure:

1. Containment:
   - Notify the client team immediately via Microsoft Teams and email.
   - (Optional) Isolate the client’s namespace if the vulnerability is critical:
     ```bash
     kubectl apply -f - <<EOF
     apiVersion: networking.k8s.io/v1
     kind: NetworkPolicy
     metadata:
       name: deny-all-${CLIENT_NAMESPACE}
       namespace: ${CLIENT_NAMESPACE}
     spec:
       podSelector: {}
       policyTypes:
       - Ingress
       - Egress
     EOF
     ```

2. Eradication:
   - Work with the client team to identify all instances of the vulnerable image.
   - Client team patches the vulnerability and provides a new image.

3. Recovery:
   - Client team redeploys the patched image.
   - SecOps verifies the fix with a Trivy scan (CI/CD or runtime).

4. Post-Incident:
   - Document the incident and share lessons learned with the client team.
   - Update client onboarding documentation to include vulnerability response expectations.

\newpage

### 4.3 Container Escape

Scenario: An attacker exploits a misconfigured container (e.g., `privileged: true`, `hostPID: true`) to gain access to the host node.

Detection:
- Tetragon: Kernel-level syscall monitoring for namespace transitions, `mount` syscalls, or `hostPath` access.
- Azure Defender for Containers: Alerts on `SuspiciousContainerActivity`.

Impact: Host node compromise, lateral movement, data exfiltration.

Control Layer: Detect/Respond (Runtime)

Response Procedure:

1. Containment:
   - (Optional) Isolate the affected node immediately:
     ```bash
     kubectl cordon <node-name>
     kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
     ```
   - (Optional) If escape is confirmed, deallocate the node via Azure:
     ```bash
     az vm deallocate --resource-group <resource-group> --name <node-vm-name>
     ```

2. Eradication:
   - (Optional) Capture memory and disk images for forensic analysis (use `kubectl cp` or node-level tools before deallocation).
   - Identify the root cause (e.g., misconfigured pod, vulnerable kernel).

3. Recovery:
   - Rebuild the node from a clean image.
   - Rejoin the node to the cluster and redeploy workloads.

4. Post-Incident:
   - Review and update pod security policies (e.g., enforce `readOnlyRootFilesystem: true`).
   - Audit all privileged pods and remove unnecessary privileges.

### 4.4 Credential/Secret Exposure
Scenario: Secrets are exposed via misconfigured `Secret` objects, environment variables, or volume mounts.

Detection:
- Tetragon: Monitors for file access to `/etc/kubernetes/secrets`, `/var/lib/kubelet/pods`, or environment variables.
- Gatekeeper: Violation for `no-secrets-in-env-vars`.
- Azure Defender for Containers: Alerts on `ExposedSecrets`.

Impact: Credential theft, unauthorized access to services or data.

Control Layer: Detect/Respond (Runtime)

Response Procedure:

1. Containment:
   - Revoke the exposed secret:
     ```bash
     kubectl delete secret <secret-name> -n <namespace>
     ```
   - Rotate all associated credentials, keys, or certificates immediately.

2. Eradication:
   - Identify the source of exposure (misconfigured pod, environment variable, etc.).
   - Remove or update the misconfiguration.

3. Recovery:
   - Redeploy the application with the new secret.
   - Verify the secret is no longer exposed:
     ```bash
     kubectl get secret <secret-name> -n <namespace> -o yaml
     ```

4. Post-Incident:
   - Enforce Gatekeeper policies to block secrets in environment variables.
   - Audit all secrets and ensure encryption at rest is enabled.

\newpage

### 4.5 Lateral Movement

Scenario: An attacker pivots from a compromised pod to other pods/nodes via weak network policies or shared volumes.

Detection:
- Cilium: Alerts on `DeniedConnection` (if blocked) or unexpected pod-to-pod traffic.
- Tetragon: Monitors for unexpected connections between pods.
- Azure Defender for Containers: Alerts on `SuspiciousNetworkActivity`.

Impact: Widespread cluster compromise, data exfiltration, service disruption.

Control Layer: Detect/Respond (Runtime + Network)

Response Procedure:

1. Containment:
   - (Optional) Isolate the affected namespace:
     ```bash
     kubectl apply -f - <<EOF
     apiVersion: networking.k8s.io/v1
     kind: NetworkPolicy
     metadata:
       name: deny-all-${NAMESPACE}
       namespace: ${NAMESPACE}
     spec:
       podSelector: {}
       policyTypes:
       - Ingress
       - Egress
     EOF
     ```
   - (Optional) If the whole cluster is at risk, restrict API server access to approved IPs.

2. Eradication:
   - Identify and remove compromised pods.
   - Review and update network policies to block unauthorized traffic.

3. Recovery:
   - Redeploy workloads with updated network policies.
   - Verify no unauthorized connections are possible.

4. Post-Incident:
   - Review and update Cilium `NetworkPolicy` rules to enforce least-privilege access.
   - Audit all network traffic patterns for anomalies.

### 4.6 Managed Identity Abuse

Scenario: An attacker exploits Azure Managed Identities assigned to pods (e.g., via Workload Identity) to access Azure resources.

Detection:
- Azure Monitor (AzureActivity / SigninLogs): Logs operations performed by the managed identity. A Sentinel analytic rule correlates unexpected operations (e.g., listing keys, reading secrets outside the pod’s expected scope) with the pod’s identity.
- Tetragon: Monitors for unusual outbound API calls to Azure management endpoints (`management.azure.com`) from the pod.
- Example Sentinel KQL rule logic:
  ```kql
  AzureActivity
  | where Caller has "<workload-identity-name>"
  | where OperationNameValue has_any ("listKeys", "read", "write")
  | where ResourceGroup != "<expected-resource-group>"
  ```

Impact: Unauthorized access to Azure services (Storage, Key Vault, etc.).

Control Layer: Detect/Respond (Cloud + Runtime)

Response Procedure:

1. Containment:
   - (Optional) Revoke the identity assignment from the pod:
     ```bash
     az identity remove-assignment --identity-name <identity-name> --resource-group <resource-group> --id <pod-identity-id>
     ```
   - (Optional) Temporarily disable the identity:
     ```bash
     az identity update --name <identity-name> --resource-group <resource-group> --enabled false
     ```

2. Eradication:
   - Identify the pod using the identity and remove it.
   - Review Azure AD logs for unauthorized access attempts.

3. Recovery:
   - Re-enable the identity with updated, least-privilege permissions.
   - Redeploy the pod with the corrected identity assignment.

4. Post-Incident:
   - Review and restrict identity permissions using Azure RBAC.
   - Audit all Workload Identity assignments for least-privilege access.

\newpage

### 4.7 API Server Abuse

Scenario: An attacker exploits exposed or misconfigured Kubernetes API servers (e.g., anonymous access, weak authentication).

Detection:
- Azure Monitor (AKS audit logs): Primary source – logs unauthorized API calls. Sentinel analytic rule `APIServerAbuse` fires on anomalies.
- Tetragon: Indirect detection via process-level outbound connections to API server endpoints.

Impact: Unauthorized access to cluster resources, data exfiltration, cluster compromise.

Control Layer: Detect/Respond (Cloud + Cluster)

Response Procedure:

1. Containment:
   - (Optional) Restrict API server access to approved IP ranges:
     ```bash
     az aks update --name <cluster-name> --resource-group <resource-group> --api-server-authorized-ip-ranges <approved-ip-range>
     ```
   - (Optional) Enable private cluster mode if not already enabled.

2. Eradication:
   - Audit API server logs for unauthorized access:
     ```bash
     az monitor logs query --resource-group <resource-group> --workspace <log-analytics-workspace> --query "KubeAuditAdmin | where OperationName == 'Create' or OperationName == 'Delete'"
     ```
   - Identify and revoke unauthorized access tokens or certificates.

3. Recovery:
   - Rotate all API server certificates and tokens.
   - Verify API server access is restricted to authorized users only.

4. Post-Incident:
   - Enforce MFA for API server access.
   - Review and update API server access controls.

### 4.8 Supply Chain Compromise

Scenario: Compromise of CI/CD dependencies (malicious base images, libraries, or tampered signed images).

Detection:
- Trivy: Scans for vulnerable or malicious dependencies in CI/CD.
- Cosign: Fails if image signatures are invalid or missing.

Impact: Deployment of compromised workloads, cluster-wide breach.

Control Layer: Prevent/Detect (CI/CD + Runtime)

Response Procedure:

1. Containment:
   - Block deployment of the compromised image in CI/CD.
   - (Optional) Isolate all pods using the compromised image:
     ```bash
     kubectl delete deployment -n <namespace> <deployment-name>
     ```

2. Eradication:
   - Identify all instances of the compromised image in the cluster.
   - Remove all affected pods/deployments.

3. Recovery:
   - Patch or replace the compromised dependency.
   - Rescan the image with Trivy and validate its signature with Cosign.
   - Redeploy the verified image.

4. Post-Incident:
   - Review and update CI/CD pipeline security (e.g., enforce signed images).
   - Audit all dependencies for vulnerabilities.

\newpage

## 5. Detection and Analysis

### Telemetry Sources

| Tool           | Telemetry Type                          | Data/Alert Flow                                        | Sentinel Analytic Rule                                 |
| -------------- | --------------------------------------- | ------------------------------------------------------ | ------------------------------------------------------ |
| Tetragon       | Kernel‑level syscalls, process activity | Logs → Azure Monitor → Sentinel (data)                 | [ContainerEscape][sentinel-container-escape-rule]      |
| Gatekeeper     | Admission control violations            | Kubernetes Events → Azure Monitor → Sentinel (data)    | [GatekeeperViolation][sentinel-gatekeeper-rule]        |
| Trivy          | Image vulnerability scans (CI/CD)       | CI/CD logs → Azure Monitor → Sentinel (data)           | [TrivyVulnerability][sentinel-trivy-rule]              |
| Trivy‑Operator | Runtime vulnerability reports           | VulnerabilityReports → Azure Monitor → Sentinel (data) | [TrivyVulnerability][sentinel-trivy-rule]              |
| Cilium         | Network flow logs                       | Logs → Azure Monitor → Sentinel (data)                 | [LateralMovement][sentinel-lateral-movement-rule]      |
| Azure Defender | Cloud‑native threats                    | Alerts → Sentinel (alert‑based incident creation)      | [SuspiciousKubernetesActivity][sentinel-defender-rule] |
| Azure Monitor  | AKS audit logs, Azure AD logs           | Logs → Sentinel (data)                                 | [APIServerAbuse][sentinel-api-abuse-rule]              |

> Note: Azure Defender sends pre-generated alerts directly to Sentinel. All other tools send log data to Azure Monitor, where Sentinel ingests them and applies analytic rules to generate incidents.

### Investigation Steps

1. Alert Triage:
   - Monitor Microsoft Sentinel for Kubernetes-specific alerts (see [Kubernetes Alerts for SIEM Integration][alerts-link]).
   - Prioritize alerts based on severity (Critical/High first).

2. Initial Investigation:
   - Use Tetragon to capture forensic data:
     ```bash
     kubectl -n kube-system exec -it deploy/tetragon -- tetragon trace pid <PID>
     ```
   - Check Kubernetes events for Gatekeeper violations:
     ```bash
     kubectl get events -n <namespace> --sort-by='.metadata.creationTimestamp'
     ```
   - Review Trivy scan logs for vulnerable/malicious images.

\newpage

## 6. Communication Plan

| Phase         | Audience                                    | Communication Method                        | Template                                     |
| ------------- | ------------------------------------------- | ------------------------------------------- | -------------------------------------------- |
| Detection     | SecOps Team                                 | Microsoft Teams (`#aurora-security-alerts`) | Initial alert with severity and description. |
| Containment   | Incident Response Team *(cross-functional)* | Microsoft Teams + Email                     | Situation report with actions taken.         |
| Recovery      | Stakeholders                                | Email + Status Page                         | Recovery status and next steps.              |
| Post-Incident | All                                         | Email + Confluence                          | RCA and lessons learned.                     |

> Incident Response Team = SecOps Analyst, Kubernetes Administrator, Application Owner, and Communications Lead (as required by the incident).

\newpage

## 7. References

- [Aurora AKS Risk Assessment][risk-assessment-link]
- [Kubernetes Alerts for SIEM Integration][alerts-link]
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes/)
- [AKS Security Baseline](https://learn.microsoft.com/en-us/security/benchmark/azure/baselines/aks-security-baseline)
- [Azure Kubernetes Service (AKS) Security Documentation](https://learn.microsoft.com/en-us/azure/aks/concepts-security)

[risk-assessment-link]: https://github.com/gccloudone-aurora/docs/security
[alerts-link]: https://github.com/gccloudone-aurora/docs/security
[sentinel-container-escape-rule]: https://github.com/gccloudone-aurora/sentinel-rules/blob/main/container-escape.kql
[sentinel-gatekeeper-rule]: https://github.com/gccloudone-aurora/sentinel-rules/blob/main/gatekeeper-violation.kql
[sentinel-trivy-rule]: https://github.com/gccloudone-aurora/sentinel-rules/blob/main/trivy-vulnerability.kql
[sentinel-lateral-movement-rule]: https://github.com/gccloudone-aurora/sentinel-rules/blob/main/lateral-movement.kql
[sentinel-defender-rule]: https://github.com/gccloudone-aurora/sentinel-rules/blob/main/suspicious-k8s-activity.kql
[sentinel-api-abuse-rule]: https://github.com/gccloudone-aurora/sentinel-rules/blob/main/api-server-abuse.kql

\newpage

## 8. Approvals

| Role           | Name | Date       | Signature |
| -------------- | ---- | ---------- | --------- |
| Security Lead  |      | 2026-07-13 |           |
| SecOps Manager |      | 2026-07-13 |           |


___
