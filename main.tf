#Cloud Engineering / Infrastructure-as-Code:
#Provide infrastructure-as-code using Terraform that will create a Kubernetes cluster in AWS . 
#You are free to use publicly available modules / components, but it is expected that you 
#understand what those modules are doing; we may ask questions about the logic within those modules. 
#(You can assume the IAM user running this has full admin permission in AWS and is running in us-east-2.)

# Using the AWS Provider Module direct from hashicorp

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0" 
    }
  }
}

# Region provided by prompt
provider "aws" {
  region = "us-east-2"
}

## Create & define an IAM Role for the Cluster to use
resource "aws_iam_role" "eks_cluster_role" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach policy to the role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

## Create the Cluster
resource "aws_eks_cluster" "codingex" {
  name     = "codingex-eks-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn

  # Setup logging
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  vpc_config {
    # Make the cluster private for security; the EKS control plane to only be accessible within your VPC
    endpoint_public_access = false
    endpoint_private_access = true
  }

  # Ensure that these are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy_attachment,
    aws_iam_role_policy_attachment.eks_cni_policy_attachment,
    aws_iam_role_policy_attachment.eks_registry_policy_attachment,
    aws_cloudwatch_log_group.codingex_logs,
  ]
}

# Output endpoint to manage cluster resources using kubectl or other Kubernetes API clients
output "endpoint" {
    description = "Endpoint for EKS control plane."
    value       = aws_eks_cluster.codingex.endpoint
    }

# Add namespaces to the cluster for organization
resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = "jenkins"
  }
}

resource "kubernetes_namespace" "weather_service" {
  metadata {
    name = "weather-service"
  }
}

# Base64 encoded certificate data used to ensure secure communication with the Kubernetes API server
output "kubeconfig-certificate-authority-data" {
    description = "Certificate authority data for the EKS cluster."
    value       = aws_eks_cluster.codingex.certificate_authority[0].data
    }

# After the EKS cluster is created, generate kubeconfig data for the Kubernetes provider. 
provider "kubernetes" {
  host                   = aws_eks_cluster.codingex.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.codingex.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.codingex.token
  load_config_file       = false
}

data "aws_eks_cluster_auth" "codingex_auth" {
  name = aws_eks_cluster.codingex.name
}

## Create & define a group role, defining specific IAM roles for your EKS nodes with only the necessary permissions, 
## avoiding broad permissions.
resource "aws_iam_role" "eks_node_group_role" {
  name = "eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach the policy to the group role for worker nodes
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSCNIPolicy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_registry_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group_role.name
}

## Create the node group 
resource "aws_eks_node_group" "codingex-node-group" {
  cluster_name    = aws_eks_cluster.codingex.name
  node_group_name = "codingex-eks-node-group"
  node_role_arn   = aws_iam_role.eks_node_group_role.arn
  subnet_ids      = [aws_subnet.codingex1.id, aws_subnet.codingex2.id] # Change/define later
  
  # Could change later based on needs
  scaling_config {
    desired_size = 1
    max_size     = 5
    min_size     = 1
  }
}

## Enabling Control Plane Logging
resource "aws_cloudwatch_log_group" "codingex_logs" {
  # The log group name format is /aws/eks/<cluster-name>/cluster
  # Reference: https://docs.aws.amazon.com/eks/latest/userguide/control-plane-logs.html
  name              = "/aws/eks/codingex/cluster"
  retention_in_days = 30
}

## Create a CloudWatch policy
resource "aws_iam_policy" "cloudwatch_policy" {
  name        = "eks-cloudwatch-policy"
  description = "EKS CloudWatch interaction policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics"
        ],
        Effect = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ],
        Effect = "Allow",
        Resource = aws_cloudwatch_log_group.codingex_logs.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_policy_attachment" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = aws_iam_policy.cloudwatch_policy.arn
}

## Adding Helm to Terraform for easy installations
provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.codingex.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.codingex.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1alpha1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        aws_eks_cluster.codingex.name
      ]
    }
  }
}

# Create an Ingress Controller
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://helm.nginx.com/stable"
  chart      = "nginx-ingress"
  namespace  = "jenkins" 

  set {
    name  = "controller.service.type"
    value = "NodePort"  # Will need to be mapped with the DNS entry
  }
}

# Install Jenkins in the Cluster
resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  namespace  = "jenkins"

  set {
    name  = "controller.adminUser"
    value = "admin"
  }

  set {
    name  = "controller.adminPassword"
    value = "password"
  }

  set {
    name  = "controller.installPlugins[0]"
    value = "kubernetes:1.29.6"
  }
}

# Map an ingress to the Jenkins Admin Console
resource "kubernetes_ingress_v1" "jenkins_ingress" {
  depends_on = [helm_release.jenkins]  # Ensure Jenkins is installed first
  metadata {
    name      = "jenkins-ingress"
    namespace = "jenkins"
    annotations = {
      "nginx.ingress.kubernetes.io/rewrite-target" = "/"
      "kubernetes.io/ingress.class"                = "nginx"
    }
  }

  spec {
    rule {
      host = "jenkins.simple.com"
      http {
        path {
          path = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "jenkins"
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }
}
