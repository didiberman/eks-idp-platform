#!/usr/bin/env bash
# Estimate VPC and ENI capacity limits for the current cluster configuration.
set -euo pipefail

VPC_CIDR="${VPC_CIDR:-10.0.0.0/16}"
AZ_COUNT="${AZ_COUNT:-3}"
SUBNET_PREFIX="${SUBNET_PREFIX:-24}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t3.large}"

eni_limit() {
  case "$1" in
    t3.medium|t3.large|m6i.large) echo 3 ;;
    m6i.xlarge) echo 4 ;;
    *) echo 3 ;;
  esac
}

ip_per_eni() {
  case "$1" in
    t3.medium) echo 6 ;;
    t3.large) echo 12 ;;
    m6i.large) echo 10 ;;
    m6i.xlarge) echo 15 ;;
    *) echo 10 ;;
  esac
}

hosts_per_subnet=$((2 ** (32 - SUBNET_PREFIX) - 5))
total_subnet_ips=$((hosts_per_subnet * AZ_COUNT))

eni_limit_val=$(eni_limit "${INSTANCE_TYPE}")
ip_per_eni_val=$(ip_per_eni "${INSTANCE_TYPE}")
pods_per_node=$(((eni_limit_val - 1) * ip_per_eni_val))

max_nodes_by_ip=$((total_subnet_ips / 30))
max_pods_estimate=$((max_nodes_by_ip * pods_per_node))

cat <<EOF
EKS IDP Platform — Capacity Estimate
=====================================
VPC CIDR:              ${VPC_CIDR}
Private subnets:       ${AZ_COUNT} x /${SUBNET_PREFIX}
Usable IPs per subnet: ~${hosts_per_subnet}
Total private IPs:     ~${total_subnet_ips}

Reference instance:    ${INSTANCE_TYPE}
ENIs per node:         ${eni_limit_val}
Pod IPs per ENI:       ~${ip_per_eni_val}
Est. pods per node:    ~${pods_per_node}

Rough ceilings (private subnets only):
  Max worker nodes:    ~${max_nodes_by_ip}
  Max pods (estimate): ~${max_pods_estimate}

Karpenter NodePool CPU limit: 100 vCPU (~25 x t3.large)

Bottleneck order (typical):
  1. VPC private subnet IP space
  2. Karpenter NodePool limits.cpu
  3. System node group (platform controllers only)
  4. NAT gateway throughput (egress-heavy workloads)

Run on a live cluster for actual numbers:
  kubectl get nodes -o wide
  kubectl get pods -A --field-selector=status.phase=Running | wc -l
  kubectl get nodeclaims -A 2>/dev/null || true
EOF
