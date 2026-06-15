#!/bin/bash
# ============================================================================
# Local Development Setup with k3d
# ============================================================================
# Creates a local k3d cluster for development and testing.
# Installs Kyverno and applies all policies locally.
#
# Usage: ./setup-local.sh
# ============================================================================

set -euo pipefail

CLUSTER_NAME="supply-chain-lab"
REGISTRY_NAME="local-registry"
REGISTRY_PORT="5555"

echo "=============================================="
echo "🏗️  Local Development Environment Setup"
echo "=============================================="

# ----------------------------------------------------------------
# Step 1: Check prerequisites
# ----------------------------------------------------------------
echo -e "\n[1/5] Checking prerequisites..."

for tool in docker k3d kubectl helm; do
    if ! command -v "$tool" &> /dev/null; then
        echo "❌ $tool not found. Please install it:"
        case $tool in
            docker) echo "   https://docs.docker.com/get-docker/" ;;
            k3d)    echo "   curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash" ;;
            kubectl) echo "   https://kubernetes.io/docs/tasks/tools/" ;;
            helm)   echo "   curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash" ;;
        esac
        exit 1
    fi
done

echo "✅ All prerequisites found"

# ----------------------------------------------------------------
# Step 2: Create local registry (for testing image push/pull)
# ----------------------------------------------------------------
echo -e "\n[2/5] Creating local registry..."

if k3d registry list | grep -q "$REGISTRY_NAME"; then
    echo "  Registry already exists, skipping..."
else
    k3d registry create "$REGISTRY_NAME" --port "$REGISTRY_PORT"
fi

echo "✅ Local registry available at localhost:${REGISTRY_PORT}"

# ----------------------------------------------------------------
# Step 3: Create k3d cluster
# ----------------------------------------------------------------
echo -e "\n[3/5] Creating k3d cluster..."

if k3d cluster list | grep -q "$CLUSTER_NAME"; then
    echo "  Cluster already exists. Delete with: k3d cluster delete $CLUSTER_NAME"
    echo "  Switching context..."
    kubectl config use-context "k3d-${CLUSTER_NAME}"
else
    k3d cluster create "$CLUSTER_NAME" \
        --registry-use "k3d-${REGISTRY_NAME}:${REGISTRY_PORT}" \
        --agents 2 \
        --k3s-arg "--disable=traefik@server:0" \
        --wait
fi

echo "✅ k3d cluster '${CLUSTER_NAME}' is ready"

# ----------------------------------------------------------------
# Step 4: Install Kyverno
# ----------------------------------------------------------------
echo -e "\n[4/5] Installing Kyverno..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "${SCRIPT_DIR}/install-kyverno.sh"

# ----------------------------------------------------------------
# Step 5: Create namespace and apply base resources
# ----------------------------------------------------------------
echo -e "\n[5/5] Setting up application namespace..."

kubectl apply -k "${SCRIPT_DIR}/../k8s/base/"

echo ""
echo "=============================================="
echo "✅ Local environment is ready!"
echo "=============================================="
echo ""
echo "Cluster:    k3d-${CLUSTER_NAME}"
echo "Registry:   localhost:${REGISTRY_PORT}"
echo "Namespace:  secure-payment"
echo ""
echo "Quick commands:"
echo "  kubectl get pods -n secure-payment     # Check app pods"
echo "  kubectl get clusterpolicy              # Check Kyverno policies"
echo "  kubectl get policyreport -A            # Check policy reports"
echo "  bash scripts/attack-simulation.sh      # Run attack demo"
echo ""
echo "To delete the local environment:"
echo "  k3d cluster delete ${CLUSTER_NAME}"
echo "  k3d registry delete k3d-${REGISTRY_NAME}"
