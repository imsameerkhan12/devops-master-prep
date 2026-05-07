#!/bin/bash
# Day 1 hands-on: Verify all tools are installed and working
set -euo pipefail

echo "=== Tool Verification ==="

echo -n "kubectl: "; kubectl version --client --short 2>/dev/null || echo "NOT FOUND"
echo -n "helm:    "; helm version --short 2>/dev/null || echo "NOT FOUND"
echo -n "docker:  "; docker --version 2>/dev/null || echo "NOT FOUND"
echo -n "aws:     "; aws --version 2>/dev/null || echo "NOT FOUND"
echo -n "terraform: "; terraform version 2>/dev/null | head -1 || echo "NOT FOUND"

echo ""
echo "=== Minikube ==="
minikube status 2>/dev/null || echo "Minikube not running — run: minikube start"

echo ""
echo "=== K8s Cluster ==="
kubectl get nodes 2>/dev/null || echo "No cluster reachable"

echo ""
echo "=== AWS Identity ==="
aws sts get-caller-identity 2>/dev/null || echo "AWS not configured — run: aws configure"
