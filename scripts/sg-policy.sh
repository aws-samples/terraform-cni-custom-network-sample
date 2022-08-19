#!/bin/bash

# kubectl auth
KUBE_CONFIG="$(mktemp)"
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --kubeconfig "${KUBE_CONFIG}"


# Create security group policy
cat <<EOF | kubectl --kubeconfig "${KUBE_CONFIG}" apply -f -
apiVersion: vpcresources.k8s.aws/v1beta1
kind: SecurityGroupPolicy
metadata:
  name: my-security-group-policy
  namespace: test-namespace
spec:
  podSelector:
    matchLabels:
      role: test-role
  securityGroups:
    groupIds:
      - ${SECURITY_GROUP}
EOF

# remobe creds
rm "${KUBE_CONFIG}"
