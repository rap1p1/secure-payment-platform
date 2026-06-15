#!/bin/bash
# ============================================================================
# Verify Image Supply Chain Artifacts
# ============================================================================
# Manually verify all supply chain security artifacts for a given image.
# Usage: ./verify-image.sh [IMAGE_DIGEST]
#
# Example:
#   ./verify-image.sh sha256:abc123...
#   ./verify-image.sh  (uses latest)
# ============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

IMAGE_BASE="ghcr.io/rap1p1/secure-payment-platform"
DIGEST="${1:-}"

echo "=============================================="
echo "🔍 Supply Chain Artifact Verification"
echo "=============================================="

# ----------------------------------------------------------------
# Check prerequisites
# ----------------------------------------------------------------
for tool in cosign slsa-verifier; do
    if ! command -v "$tool" &> /dev/null; then
        echo -e "${RED}❌ $tool not found. Install it first:${NC}"
        if [ "$tool" == "cosign" ]; then
            echo "   go install github.com/sigstore/cosign/v2/cmd/cosign@latest"
        else
            echo "   go install github.com/slsa-framework/slsa-verifier/v2/cli/slsa-verifier@latest"
        fi
        exit 1
    fi
done

# ----------------------------------------------------------------
# Get latest digest if not provided
# ----------------------------------------------------------------
if [ -z "$DIGEST" ]; then
    echo -e "\n${YELLOW}No digest provided. Fetching latest...${NC}"
    DIGEST=$(docker manifest inspect "${IMAGE_BASE}:latest" 2>/dev/null | \
        jq -r '.config.digest // .manifests[0].digest')
    
    if [ -z "$DIGEST" ] || [ "$DIGEST" == "null" ]; then
        echo -e "${RED}❌ Could not fetch latest digest. Provide one manually.${NC}"
        echo "Usage: $0 sha256:abc123..."
        exit 1
    fi
fi

IMAGE="${IMAGE_BASE}@${DIGEST}"
echo -e "\n${BLUE}Image: ${IMAGE}${NC}"
echo ""

PASSED=0
FAILED=0

# ----------------------------------------------------------------
# Check 1: Image Signature (Cosign Keyless)
# ----------------------------------------------------------------
echo -e "${YELLOW}━━━ Check 1/3: Image Signature (Cosign Keyless) ━━━${NC}"
if cosign verify "$IMAGE" \
    --certificate-identity-regexp="github.com/rap1p1/secure-payment-platform" \
    --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
    2>/dev/null | jq '.[0] | {issuer: .optional.Issuer, subject: .optional.Subject, timestamp: .optional."Bundle.Payload.logIndex"}' 2>/dev/null; then
    echo -e "${GREEN}✅ Image signature: VERIFIED${NC}"
    ((PASSED++))
else
    echo -e "${RED}❌ Image signature: FAILED${NC}"
    ((FAILED++))
fi
echo ""

# ----------------------------------------------------------------
# Check 2: SBOM Attestation (CycloneDX)
# ----------------------------------------------------------------
echo -e "${YELLOW}━━━ Check 2/3: SBOM Attestation (CycloneDX) ━━━${NC}"
if cosign verify-attestation --type cyclonedx "$IMAGE" \
    --certificate-identity-regexp="github.com/rap1p1/secure-payment-platform" \
    --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
    2>/dev/null | jq -r '.payload' | base64 -d 2>/dev/null | \
    jq '{format: .predicateType, components: (.predicate.components // .predicate | length)}' 2>/dev/null; then
    echo -e "${GREEN}✅ SBOM attestation: VERIFIED${NC}"
    ((PASSED++))
else
    echo -e "${RED}❌ SBOM attestation: FAILED${NC}"
    ((FAILED++))
fi
echo ""

# ----------------------------------------------------------------
# Check 3: SLSA Provenance (Level 3)
# ----------------------------------------------------------------
echo -e "${YELLOW}━━━ Check 3/3: SLSA Provenance (Level 3) ━━━${NC}"
if slsa-verifier verify-image "$IMAGE" \
    --source-uri "github.com/rap1p1/secure-payment-platform" \
    --source-branch "main" 2>&1; then
    echo -e "${GREEN}✅ SLSA provenance: VERIFIED (Level 3)${NC}"
    ((PASSED++))
else
    echo -e "${RED}❌ SLSA provenance: FAILED${NC}"
    ((FAILED++))
fi

# ----------------------------------------------------------------
# Summary
# ----------------------------------------------------------------
echo ""
echo "=============================================="
echo "📊 VERIFICATION SUMMARY"
echo "=============================================="
echo -e "  Passed: ${GREEN}${PASSED}/3${NC}"
echo -e "  Failed: ${RED}${FAILED}/3${NC}"
echo ""

if [ "$FAILED" -eq 0 ]; then
    echo -e "${GREEN}🛡️  ALL CHECKS PASSED — Image is safe to deploy!${NC}"
    exit 0
else
    echo -e "${RED}🚨 VERIFICATION FAILED — DO NOT DEPLOY THIS IMAGE!${NC}"
    exit 1
fi
