# Demo Runbook: SLSA Level 3 Supply Chain Security

> Step-by-step guide for presenting this project to recruiters, interviewers, or team leads.

---

## Pre-Demo Setup Checklist

- [ ] GitHub repo `rap1p1/secure-payment-platform` is created and public
- [ ] GitHub Actions workflow has run at least once successfully
- [ ] k3s cluster is accessible with Kyverno installed
- [ ] `cosign` and `slsa-verifier` installed locally
- [ ] Terminal with color support open (for script output)

---

## Demo Script (10-15 minutes)

### Part 1: The Problem (2 min)

**Talking points:**
> "Traditional security focuses on scanning code for vulnerabilities. But recent attacks like SolarWinds and xz-utils showed that attackers target the **build pipeline itself**. They don't need to break your code — they just need to compromise the process that builds your code."

> "This project implements SLSA Level 3, which answers one question: **How do you prove that this artifact was actually built from your source code, on a trusted system, without tampering?**"

---

### Part 2: The Pipeline (3 min)

**Show the GitHub Actions workflow:**
1. Open `https://github.com/rap1p1/secure-payment-platform/actions`
2. Click on the latest successful run
3. Walk through the jobs:

```
Job 1: Build → Sign → SBOM
├── Build Docker image (multi-stage, distroless)
├── Generate SBOM with Syft (CycloneDX format)
├── Sign image with Cosign (keyless, GitHub OIDC)
└── Attach SBOM as signed attestation

Job 2: SLSA Provenance (Level 3)
└── Isolated builder generates non-falsifiable provenance

Job 3: Verify All Artifacts
├── Verify image signature ✅
├── Verify SBOM attestation ✅
└── Verify SLSA provenance ✅
```

**Key point:**
> "Notice Job 2 runs as a **separate, isolated workflow**. Even if my GitHub account is compromised, the attacker cannot fake the provenance. This is what makes it Level 3."

---

### Part 3: Manual Verification (2 min)

**Run the verification script:**
```bash
bash scripts/verify-image.sh
```

**Expected output:**
```
━━━ Check 1/3: Image Signature (Cosign Keyless) ━━━
✅ Image signature: VERIFIED

━━━ Check 2/3: SBOM Attestation (CycloneDX) ━━━
✅ SBOM attestation: VERIFIED

━━━ Check 3/3: SLSA Provenance (Level 3) ━━━
✅ SLSA provenance: VERIFIED (Level 3)

🛡️ ALL CHECKS PASSED — Image is safe to deploy!
```

**Key point:**
> "Anyone can verify this image without special keys. The signatures are based on the **identity** of the GitHub Actions workflow, recorded in a public transparency log."

---

### Part 4: Attack Simulation (3 min) ⭐ Most Impressive Part

**Run the attack simulation:**
```bash
bash scripts/attack-simulation.sh
```

**Walk through each scenario:**

1. **Scenario 1: Unsigned nginx image**
   > "An attacker tries to deploy a vanilla nginx image. Kyverno immediately blocks it because there's no valid Cosign signature from our pipeline."

2. **Scenario 2: Unsigned GHCR image**
   > "A developer bypasses the pipeline and pushes directly to GHCR. Even though it's from our registry, Kyverno blocks it because it wasn't signed by our trusted CI workflow."

3. **Scenario 3: Properly signed image**
   > "The image that went through our full pipeline — signed, with SBOM, with SLSA provenance — deploys successfully."

**Key point:**
> "This is **zero-trust artifact verification**. The cluster doesn't trust any image by default. It verifies the full chain: signature, provenance, and SBOM — every single time."

---

### Part 5: Kyverno Policies (2 min)

**Show the three policies:**
```bash
kubectl get clusterpolicy
```

```
NAME                      ACTION    READY
require-signed-images     Enforce   True
require-slsa-provenance   Enforce   True
require-sbom-attestation  Enforce   True
```

**Explain the layered defense:**
> "We have three separate policies, each checking a different aspect:
> 1. **Signature**: Was this image signed by our CI pipeline?
> 2. **Provenance**: Was it built by the SLSA trusted builder from our repo?
> 3. **SBOM**: Do we know exactly what's inside this image?
> 
> All three must pass. If any one fails, deployment is blocked."

---

### Part 6: Architecture Highlights (2 min)

**Key points to mention:**

1. **Zero static secrets**
   > "No signing keys are stored anywhere. We use GitHub OIDC + Sigstore for short-lived certificates."

2. **Distroless base image**
   > "The runtime image has no shell, no package manager. An attacker who somehow gets into the container can't do anything."

3. **Digest-pinned images**
   > "Kubernetes manifests reference images by digest, not tag. This prevents tag mutation attacks."

4. **GitOps with ArgoCD**
   > "The CD pipeline verifies all artifacts, then updates the Git manifest. ArgoCD auto-syncs to the cluster. Humans never touch kubectl."

---

## Anticipated Interview Questions

### Q: "Why not just scan for vulnerabilities?"
> "Scanning (Trivy, Snyk) finds known CVEs. But it can't detect if the image was tampered with during build, or if someone replaced it on the registry. SLSA addresses **integrity**, not just **vulnerability**. We do both — Trivy scan is part of our pipeline too."

### Q: "What happens if Sigstore goes down?"
> "In our current setup, signing would fail and the pipeline would not push the image. For enterprise environments, you can run a self-hosted Sigstore stack. But Sigstore's public instance has had 99.9%+ uptime since launch."

### Q: "How does this compare to Docker Content Trust?"
> "DCT uses Notary v1, which requires managing long-lived TUF keys. Cosign keyless with OIDC eliminates key management entirely. Plus, Cosign natively supports attestations (SBOM, provenance), which DCT doesn't."

### Q: "Can a developer bypass Kyverno?"
> "Only if they have cluster-admin access to delete the Kyverno admission webhook. In a real environment, RBAC prevents this. The Kyverno namespace would be locked down with additional policies."

### Q: "What's the performance impact of Kyverno?"
> "Kyverno adds ~50-100ms to pod admission. It caches signature verification results, so repeated deploys of the same image are faster. In practice, this is negligible compared to image pull time."

---

## Troubleshooting During Demo

| Issue | Quick Fix |
|-------|-----------|
| `cosign verify` fails | Check GHCR login: `docker login ghcr.io` |
| Kyverno not blocking | Verify policy: `kubectl get clusterpolicy -o yaml` |
| SLSA verifier fails | Ensure using `slsa-verifier` v2.x, not v1 |
| ArgoCD out of sync | Manual sync: `argocd app sync secure-payment-platform` |
| Pipeline fails at OIDC | Check repo Settings → Actions → "Allow GitHub Actions to create and approve pull requests" |
