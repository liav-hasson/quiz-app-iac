# AWS Load Balancer Controller outputs removed - now managed via script-based approach

output "eks_addons" {
  description = "Map of EKS add-ons and their versions"
  value = {
    vpc_cni    = aws_eks_addon.vpc_cni.addon_version
    coredns    = aws_eks_addon.coredns.addon_version
    kube_proxy = aws_eks_addon.kube_proxy.addon_version
  }
}