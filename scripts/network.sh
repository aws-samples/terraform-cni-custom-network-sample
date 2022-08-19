#!/bin/bash

# kubectl auth
KUBE_CONFIG="$(mktemp)"
aws eks update-kubeconfig --name "${CLUSTER_NAME}" --kubeconfig "${KUBE_CONFIG}"

# CNI env configurations
kubectl --kubeconfig "${KUBE_CONFIG}" set env daemonset aws-node -n kube-system AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG=true
kubectl --kubeconfig "${KUBE_CONFIG}" set env daemonset aws-node -n kube-system ENI_CONFIG_LABEL_DEF=topology.kubernetes.io/zone

# Security group for pod env configurations
kubectl --kubeconfig "${KUBE_CONFIG}" set env daemonset aws-node -n kube-system ENABLE_POD_ENI=true
kubectl --kubeconfig "${KUBE_CONFIG}" patch daemonset aws-node \
  -n kube-system \
  -p '{"spec": {"template": {"spec": {"initContainers": [{"env":[{"name":"DISABLE_TCP_EARLY_DEMUX","value":"true"}],"name":"aws-vpc-cni-init"}]}}}}'

# set up ENIConfig 
subnet_a=$(echo ${SUBNETS} |awk -F"," '{print $1}')
subnet_b=$(echo ${SUBNETS} |awk -F"," '{print $2}')
subnet_c=$(echo ${SUBNETS} |awk -F"," '{print $3}')

cat <<EOF | kubectl --kubeconfig "${KUBE_CONFIG}" apply -f -
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata:
 name: "ap-southeast-2a"
spec:
 subnet: "${subnet_a}"
 securityGroups:
 - ${NODE_SG}
EOF

cat <<EOF | kubectl --kubeconfig "${KUBE_CONFIG}" apply -f -
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata:
 name: "ap-southeast-2b"
spec:
 subnet: "${subnet_b}"
 securityGroups:
 - ${NODE_SG}
EOF

cat <<EOF | kubectl --kubeconfig "${KUBE_CONFIG}" apply -f -
apiVersion: crd.k8s.amazonaws.com/v1alpha1
kind: ENIConfig
metadata:
 name: "ap-southeast-2c"
spec:
 subnet: "${subnet_c}"
 securityGroups:
 - ${NODE_SG}
EOF

# remobe creds
rm "${KUBE_CONFIG}"
