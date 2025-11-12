# Use OIDC provider ARN passed from prod_cluster module
# This avoids circular dependency issues on first apply
locals {
  oidc_provider_arn        = var.oidc_provider_arn
  oidc_provider_url_suffix = element(split("oidc-provider/", var.oidc_provider_arn), 1)
  oidc_provider_url        = local.oidc_provider_url_suffix
}
