/*
 * Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
 * SPDX-License-Identifier: MIT-0
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this
 * software and associated documentation files (the "Software"), to deal in the Software
 * without restriction, including without limitation the rights to use, copy, modify,
 * merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
 * PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

# STEP 1: Create VPC with public, private and intra subnets
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.7.0"
  name                  = "terraform-demo-vpc"
  cidr                  = "10.0.0.0/16"
  secondary_cidr_blocks = ["100.64.0.0/16"]
  azs                   = ["${local.region}a", "${local.region}b", "${local.region}c"]
  private_subnets       = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  intra_subnets         = [ "100.64.1.0/24", "100.64.2.0/24", "100.64.3.0/24"]
  public_subnets        = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_nat_gateway    = true
  single_nat_gateway    = true
  enable_dns_hostnames  = true
}
# private nat gateway
resource "aws_nat_gateway" "private_nat" {
  connectivity_type = "private"
  subnet_id         = module.vpc.private_subnets[0]
}
resource "aws_route" "intra_subnets_default_gateway" {
  route_table_id            = module.vpc.intra_route_table_ids[0]
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id            = aws_nat_gateway.private_nat.id
  depends_on                = [aws_nat_gateway.private_nat]
}

# STEP 2: Create EKS cluster 
module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = local.cluster_name
  cluster_version = "1.21"
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id
  cluster_enabled_log_types = [ "audit", "api", "authenticator", "controllerManager", "scheduler" ]
}

# STEP 3: Configure CNI custom network 
resource "null_resource" "cni_patch" {
  triggers = {
    cluster_name  = local.cluster_name
    node_sg       = module.eks.node_security_group_id
    intra_subnets = join(",", module.vpc.intra_subnets)
    content       = file("${path.module}/scripts/network.sh")
  }
  provisioner "local-exec" {
    environment = {
      CLUSTER_NAME = self.triggers.cluster_name
      NODE_SG      = self.triggers.node_sg
      SUBNETS      = self.triggers.intra_subnets
    }
    command     = "${path.cwd}/scripts/network.sh"
    interpreter = ["bash"]
  }
  depends_on = [
    module.eks
  ]
}

# STEP 4: Create managed node group
resource "aws_eks_node_group" "default" {
  cluster_name  = local.cluster_name
  node_group_name = "${local.cluster_name}-node-group-default"
  node_role_arn   = aws_iam_role.eks_cluster_node_role.arn
  subnet_ids      = module.vpc.private_subnets
  instance_types  = [ "c5.large" ]
  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }
  depends_on = [
    null_resource.cni_patch,
    module.vpc
  ]
}

# STEP 5: Configure security group policy
resource "null_resource" "sg_policy" {
  triggers = {
    node_group    = aws_eks_node_group.default.id
    cluster_name  = local.cluster_name
    sg       = aws_security_group.example_sg.id
    content       = file("${path.module}/scripts/network.sh")
  }
  provisioner "local-exec" {
    environment = {
      CLUSTER_NAME   = self.triggers.cluster_name
      SECURITY_GROUP = self.triggers.sg
    }
    command     = "${path.cwd}/scripts/sg-policy.sh"
    interpreter = ["bash"]
  }
  depends_on = [
    aws_eks_node_group.default,
    aws_security_group.example_sg,
    kubernetes_namespace.example,
    module.vpc
  ]
}

# STEP 6: Launch an example deployment
resource "kubernetes_namespace" "example" {
  metadata {
    name = "test-namespace"
  }
}
resource "kubernetes_deployment" "example" {
  metadata {
    name = "deployment-example"
    namespace = "test-namespace"
    labels = {
      test = "MyExampleApp"
    }
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        test = "MyExampleApp"
      }
    }
    template {
      metadata {
        labels = {
          test = "MyExampleApp"
          role = "test-role"
        }
      }
      spec {
        container {
          image = "nginx:latest"
          name  = "example"
        }
      }
    }
  }
  depends_on = [
    null_resource.sg_policy
  ]
}
