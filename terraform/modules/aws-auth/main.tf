# Data sources for EKS cluster information
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# Create or update aws-auth ConfigMap
resource "kubernetes_config_map_v1" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "terraform.io/purpose"         = "kubespray-eks-authentication"
    }
  }

  data = {
    mapRoles = yamlencode([
      {
        rolearn  = var.kubespray_iam_role_arn
        username = "kubespray-user"
        groups   = ["system:masters"]
      }
    ])
  }

  # Ensure this runs after the cluster and nodes are ready
  depends_on = [
    data.aws_eks_cluster.cluster
  ]
}