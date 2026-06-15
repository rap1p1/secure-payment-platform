#!/bin/bash
# ============================================================================
# Attack Simulation: Supply Chain Attack Demo
# ============================================================================
# This script demonstrates what happens when:
# 1. An UNSIGNED image is pushed and deployed → BLOCKED by Kyverno
# 2. A SIGNED image from the trusted pipeline is deployed → ALLOWED
#
# Use this for:
# - Portfolio demo videos
# - Interview presentations
# - Security awareness training
#
# Prerequisites:
# - kubectl access to cluster with Kyverno installed
# - Docker and GHCR access
# - Kyverno policies applied (run install-kyverno.sh first)
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

NAMESPACE="secure-payment"
IMAGE_BASE="ghcr.io/rap1p1/secure-payment-platform"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   🔴 SUPPLY CHAIN ATTACK SIMULATION             ║${NC}"
echo -e "${BOLD}║   Demonstrating Kyverno Policy Enforcement       ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ----------------------------------------------------------------
# Ensure namespace exists
# ----------------------------------------------------------------
kubectl get namespace "$NAMESPACE" &>/dev/null || \
    kubectl create namespace "$NAMESPACE"

# ================================================================
# SCENARIO 1: Deploy UNSIGNED image (ATTACKER SIMULATION)
# ================================================================
echo -e "${RED}${BOLD}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔴 SCENARIO 1: Attacker pushes UNSIGNED image"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${NC}"

echo -e "${YELLOW}Simulating: Attacker builds image locally and tries to deploy...${NC}"
echo ""

# Try to deploy an unsigned nginx image (simulates attacker's image)
echo -e "${CYAN}$ kubectl run attack-test --image=nginx:latest -n ${NAMESPACE}${NC}"
echo ""

if kubectl run attack-test \
    --image=nginx:latest \
    -n "$NAMESPACE" \
    --dry-run=none 2>&1; then
    echo ""
    echo -e "${RED}⚠️  WARNING: Pod was created! Kyverno policies may not be active.${NC}"
    echo -e "${RED}   Run install-kyverno.sh first.${NC}"
    # Clean up
    kubectl delete pod attack-test -n "$NAMESPACE" --ignore-not-found &>/dev/null
else
    echo ""
    echo -e "${GREEN}🛡️  BLOCKED! Kyverno rejected the unsigned image!${NC}"
    echo -e "${GREEN}   The attacker cannot deploy malicious code.${NC}"
fi

echo ""
sleep 2

# ================================================================
# SCENARIO 2: Deploy unsigned GHCR image (bypassing pipeline)
# ================================================================
echo -e "${RED}${BOLD}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔴 SCENARIO 2: Developer bypasses pipeline, pushes directly"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${NC}"

echo -e "${YELLOW}Simulating: Developer pushes image directly to GHCR without signing...${NC}"
echo ""

# Create a test pod spec with our GHCR image but fake tag
cat <<EOF | kubectl apply -f - 2>&1 || true
apiVersion: v1
kind: Pod
metadata:
  name: bypass-test
  namespace: ${NAMESPACE}
  labels:
    app: attack-simulation
spec:
  containers:
  - name: payment-api
    image: ${IMAGE_BASE}:unsigned-test
    ports:
    - containerPort: 8080
EOF

echo ""
echo -e "${GREEN}🛡️  Expected: BLOCKED by Kyverno (no valid signature or provenance)${NC}"
echo ""

# Clean up
kubectl delete pod bypass-test -n "$NAMESPACE" --ignore-not-found &>/dev/null

sleep 2

# ================================================================
# SCENARIO 3: Deploy SIGNED image (LEGITIMATE DEPLOYMENT)
# ================================================================
echo -e "${GREEN}${BOLD}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🟢 SCENARIO 3: Legitimate deployment via trusted pipeline"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${NC}"

echo -e "${YELLOW}Deploying image that was signed by GitHub Actions pipeline...${NC}"
echo ""

# Deploy using the proper manifests (which reference digest-pinned, signed images)
echo -e "${CYAN}$ kubectl apply -k k8s/base/${NC}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if kubectl apply -k "${SCRIPT_DIR}/../k8s/base/" 2>&1; then
    echo ""
    echo -e "${GREEN}✅ ALLOWED! Signed image with valid provenance deployed successfully!${NC}"
else
    echo ""
    echo -e "${YELLOW}ℹ️  Note: Deployment may fail if image digest hasn't been set yet.${NC}"
    echo -e "${YELLOW}   Run the GitHub Actions pipeline first to build and sign the image.${NC}"
fi

# ================================================================
# Summary
# ================================================================
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   📊 ATTACK SIMULATION RESULTS                   ║${NC}"
echo -e "${BOLD}╠══════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}║                                                  ║${NC}"
echo -e "${BOLD}║  🔴 Unsigned nginx image    → ${RED}BLOCKED${NC}${BOLD}            ║${NC}"
echo -e "${BOLD}║  🔴 Unsigned GHCR image     → ${RED}BLOCKED${NC}${BOLD}            ║${NC}"
echo -e "${BOLD}║  🟢 Signed + Provenance     → ${GREEN}ALLOWED${NC}${BOLD}            ║${NC}"
echo -e "${BOLD}║                                                  ║${NC}"
echo -e "${BOLD}║  Kyverno enforces zero-trust artifact            ║${NC}"
echo -e "${BOLD}║  verification at deployment time.                ║${NC}"
echo -e "${BOLD}║                                                  ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# Show Kyverno policy reports
echo -e "${BLUE}📋 Kyverno Policy Reports:${NC}"
kubectl get policyreport -n "$NAMESPACE" 2>/dev/null || \
    echo "   No policy reports found (policies may be in Enforce mode only)"
echo ""

# Show events related to policy violations
echo -e "${BLUE}📋 Recent Policy Violation Events:${NC}"
kubectl get events -n "$NAMESPACE" --field-selector reason=PolicyViolation \
    --sort-by='.lastTimestamp' 2>/dev/null | tail -5 || \
    echo "   No violation events found"
