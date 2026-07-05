#!/usr/bin/env bash
# Run scalability benchmarks against a live cluster and capture snapshots.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/results"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RESULT_FILE="${RESULTS_DIR}/${TIMESTAMP}-benchmark.txt"

mkdir -p "${RESULTS_DIR}"

log() {
  echo "[$(date -u +%H:%M:%S)] $*" | tee -a "${RESULT_FILE}"
}

snapshot() {
  local label="$1"
  {
    echo ""
    echo "=== ${label} ==="
    echo "--- Nodes ---"
    kubectl get nodes -o wide 2>/dev/null || echo "kubectl unavailable"
    echo ""
    echo "--- NodeClaims (Karpenter) ---"
    kubectl get nodeclaims -A 2>/dev/null || echo "no nodeclaims"
    echo ""
    echo "--- Pods (load-testing) ---"
    kubectl get pods -n load-testing -o wide 2>/dev/null || echo "namespace not found"
    echo ""
    echo "--- HPA (golden-path) ---"
    kubectl get hpa -n golden-path 2>/dev/null || echo "hpa not found"
    echo ""
    echo "--- Pending pods cluster-wide ---"
    kubectl get pods -A --field-selector=status.phase=Pending 2>/dev/null || true
  } | tee -a "${RESULT_FILE}"
}

require_kubectl() {
  if ! kubectl cluster-info &>/dev/null; then
    echo "ERROR: kubectl cannot reach the cluster. Run:"
    echo "  aws eks update-kubeconfig --region eu-west-1 --name eks-idp-dev"
    exit 1
  fi
}

run_karpenter_test() {
  log "TEST 1: Karpenter scale-up (40 pods @ 500m CPU)"
  kubectl apply -k "${SCRIPT_DIR}" >/dev/null
  log "Applied load-testing manifests. Waiting 30s for scheduling..."
  sleep 30
  snapshot "Karpenter scale-up @ 30s"
  log "Waiting 60s more for node provisioning..."
  sleep 60
  snapshot "Karpenter scale-up @ 90s"
}

run_hpa_test() {
  log "TEST 2: HPA stress (golden-path target)"
  if ! kubectl get deployment golden-path -n golden-path &>/dev/null; then
    log "SKIP: golden-path deployment not found"
    return
  fi
  snapshot "HPA baseline"
  log "HPA load generator already in kustomization. Waiting 3m for scale-out..."
  sleep 180
  snapshot "HPA after 3m load"
}

run_kyverno_test() {
  log "TEST 3: Kyverno admission stress (100 pods)"
  kubectl delete job kyverno-admission-stress -n load-testing --ignore-not-found >/dev/null
  kubectl apply -f "${SCRIPT_DIR}/kyverno-admission/job.yaml" >/dev/null
  local start end duration
  start=$(date +%s)
  kubectl wait --for=condition=complete job/kyverno-admission-stress -n load-testing --timeout=300s 2>/dev/null || true
  end=$(date +%s)
  duration=$((end - start))
  log "Kyverno job completed in ${duration}s"
  snapshot "Kyverno admission stress complete"
}

cleanup() {
  log "Cleaning up load-testing resources..."
  kubectl delete -k "${SCRIPT_DIR}" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete job kyverno-admission-stress -n load-testing --ignore-not-found >/dev/null 2>&1 || true
  log "Cleanup done"
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [command]

Commands:
  all         Run all benchmarks (default)
  karpenter   Karpenter scale-up test only
  hpa         HPA stress test only
  kyverno     Kyverno admission stress only
  snapshot    Capture cluster state only
  capacity    Print theoretical capacity limits
  cleanup     Remove load-testing resources

Results written to: ${RESULTS_DIR}/
EOF
}

main() {
  local cmd="${1:-all}"
  case "${cmd}" in
    all)
      require_kubectl
      log "Starting benchmark run ${TIMESTAMP}"
      snapshot "Baseline"
      run_karpenter_test
      run_hpa_test
      run_kyverno_test
      log "Benchmark complete. Results: ${RESULT_FILE}"
      log "Run './run-benchmark.sh cleanup' when finished reviewing."
      ;;
    karpenter)
      require_kubectl
      run_karpenter_test
      ;;
    hpa)
      require_kubectl
      kubectl apply -k "${SCRIPT_DIR}" >/dev/null
      run_hpa_test
      ;;
    kyverno)
      require_kubectl
      kubectl apply -f "${SCRIPT_DIR}/namespace.yaml" >/dev/null
      run_kyverno_test
      ;;
    snapshot)
      require_kubectl
      snapshot "Manual snapshot"
      ;;
    capacity)
      bash "${SCRIPT_DIR}/capacity-calculator.sh" | tee -a "${RESULT_FILE}"
      ;;
    cleanup)
      require_kubectl
      cleanup
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
