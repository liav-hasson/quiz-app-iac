# Use OIDC provider ARN passed from prod_cluster module
# This avoids circular dependency issues on first apply
locals {
  oidc_provider_arn = var.oidc_provider_arn
  # Extract the OIDC URL from the ARN
  # ARN format: arn:aws:iam::ACCOUNT:oidc-provider/oidc.eks.REGION.amazonaws.com/id/XXXXX
  oidc_provider_url = replace(var.oidc_provider_arn, "/.*(oidc\\.eks\\..*)$/", "$1")
}
