#!/bin/bash
# ============================================================================
# Install Kyverno on k3s Cluster
# ============================================================================
# Installs Kyverno via Helm and applies all supply chain security policies.
# Run this script on a machine with kubectl access to your k3s cluster.
# ============================================================================

set -euo pipefail

echo "=============================================="
echo "🛡️  Kyverno Installation & Policy Setup"
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ----------------------------------------------------------------
# Step 1: Check prerequisites
# ----------------------------------------------------------------
echo -e "\n${YELLOW}[1/5] Checking prerequisites...${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl not found. Please install kubectl first.${NC}"
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo -e "${YELLOW}⚠️  Helm not found. Installing...${NC}"
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Verify cluster connection
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster. Check your kubeconfig.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites check passed${NC}"

# ----------------------------------------------------------------
# Step 2: Add Kyverno Helm repo
# ----------------------------------------------------------------
echo -e "\n${YELLOW}[2/5] Adding Kyverno Helm repository...${NC}"

helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

echo -e "${GREEN}✅ Helm repo added${NC}"

# ----------------------------------------------------------------
# Step 3: Install Kyverno
# ----------------------------------------------------------------
echo -e "\n${YELLOW}[3/5] Installing Kyverno...${NC}"

helm upgrade --install kyverno kyverno/kyverno \
    --namespace kyverno \
    --create-namespace \
    --set admissionController.replicas=1 \
    --set backgroundController.replicas=1 \
    --set cleanupController.replicas=1 \
    --set reportsController.replicas=1 \
    --wait \
    --timeout 5m

echo -e "${GREEN}✅ Kyverno installed${NC}"

# ----------------------------------------------------------------
# Step 4: Wait for Kyverno to be ready
# ----------------------------------------------------------------
echo -e "\n${YELLOW}[4/5] Waiting for Kyverno pods to be ready...${NC}"

kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/instance=kyverno \
    -n kyverno \
    --timeout=120s

echo -e "${GREEN}✅ Kyverno is ready${NC}"

# ----------------------------------------------------------------
# Step 5: Apply supply chain security policies
# ----------------------------------------------------------------
echo -e "\n${YELLOW}[5/5] Applying supply chain security policies...${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_DIR="${SCRIPT_DIR}/../k8s/policies"

if [ -d "$POLICY_DIR" ]; then
    for policy in "$POLICY_DIR"/*.yaml; do
        echo "  📋 Applying $(basename "$policy")..."
        kubectl apply -f "$policy"
    done
else
    echo -e "${RED}❌ Policy directory not found: ${POLICY_DIR}${NC}"
    exit 1
fi

echo -e "${GREEN}✅ All policies applied${NC}"

# ----------------------------------------------------------------
# Summary
# ----------------------------------------------------------------
echo ""
echo "=============================================="
echo -e "${GREEN}🛡️  Kyverno Setup Complete!${NC}"
echo "=============================================="
echo ""
echo "Installed policies:"
kubectl get clusterpolicy -o custom-columns=NAME:.metadata.name,ACTION:.spec.validationFailureAction,READY:.status.conditions[-1].status
echo ""
echo "To test, try deploying an unsigned image:"
echo "  kubectl run test-unsigned --image=nginx:latest -n secure-payment"
echo "  → Expected: BLOCKED by require-signed-images policy"
echo ""
echo "To check policy reports:"
echo "  kubectl get policyreport -A"
