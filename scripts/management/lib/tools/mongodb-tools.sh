#!/bin/bash
# tools/mongodb-tools.sh
# Helper utilities for ad-hoc MongoDB tooling (e.g., mongo-express)

# Guard against double-loading
[[ -n "${_TOOL_MONGODB_LOADED:-}" ]] && return 0
_TOOL_MONGODB_LOADED=1

# =============================================================================
# Configuration
# =============================================================================

MONGO_EXPRESS_NAMESPACE="${MONGO_EXPRESS_NAMESPACE:-db-tools}"
MONGO_EXPRESS_RELEASE="${MONGO_EXPRESS_RELEASE:-mongo-express}"
MONGO_EXPRESS_SECRET="${MONGO_EXPRESS_SECRET:-mongo-express-credentials}"
MONGO_EXPRESS_HELM_REPO_NAME="${MONGO_EXPRESS_HELM_REPO_NAME:-cowboysysop}"
MONGO_EXPRESS_HELM_REPO_URL="${MONGO_EXPRESS_HELM_REPO_URL:-https://cowboysysop.github.io/charts}"
MONGO_EXPRESS_MONGODB_HOST="${MONGO_EXPRESS_MONGODB_HOST:-mongodb.mongodb.svc.cluster.local}"
MONGO_EXPRESS_MONGODB_PORT="${MONGO_EXPRESS_MONGODB_PORT:-27017}"
MONGO_ROOT_PASSWORD_SSM_PATH="${MONGO_ROOT_PASSWORD_SSM_PATH:-/quiz-app/mongodb/root-password}"
MONGO_EXPRESS_ROLLOUT_TIMEOUT="${MONGO_EXPRESS_ROLLOUT_TIMEOUT:-180s}"

# =============================================================================
# Helper Functions
# =============================================================================

_mongo_require_binary() {
    local bin="$1"
    if ! command -v "$bin" >/dev/null 2>&1; then
        log_error "Required command '$bin' not found in PATH"
        return 1
    fi
}

_mongo_ensure_namespace() {
    local namespace="$1"
    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log_info "Creating namespace $namespace"
        kubectl create namespace "$namespace" >/dev/null
    fi
}

_mongo_fetch_ssm_parameter() {
    local parameter_name="$1"
    if [[ -z "$parameter_name" ]]; then
        log_error "SSM parameter name cannot be empty"
        return 1
    fi

    aws ssm get-parameter \
        --name "$parameter_name" \
        --with-decryption \
        --region "$AWS_REGION" \
        --query 'Parameter.Value' \
        --output text 2>/dev/null
}

_mongo_generate_secret() {
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -hex 32
    else
        python3 -c "import secrets; print(secrets.token_hex(32))"
    fi
}

_mongo_get_secret_value() {
    local namespace="$1"
    local secret_name="$2"
    local key="$3"

    local encoded
    encoded=$(kubectl get secret "$secret_name" -n "$namespace" \
        -o "jsonpath={.data.$key}" 2>/dev/null || echo "")
    
    if [[ -n "$encoded" ]]; then
        echo "$encoded" | base64 -d 2>/dev/null || echo "$encoded" | base64 --decode 2>/dev/null
    fi
}

_mongo_apply_secret() {
    local namespace="$1"
    local secret_name="$2"
    local admin_password="$3"

    local existing_cookie existing_session
    existing_cookie=$(_mongo_get_secret_value "$namespace" "$secret_name" "site-cookie-secret")
    existing_session=$(_mongo_get_secret_value "$namespace" "$secret_name" "site-session-secret")

    local cookie_secret="${existing_cookie:-$(_mongo_generate_secret)}"
    local session_secret="${existing_session:-$(_mongo_generate_secret)}"

    log_info "Reconciling secret $secret_name"

    kubectl -n "$namespace" create secret generic "$secret_name" \
        --from-literal=mongodb-admin-password="$admin_password" \
        --from-literal=site-cookie-secret="$cookie_secret" \
        --from-literal=site-session-secret="$session_secret" \
        --dry-run=client -o yaml | kubectl apply -f - >/dev/null
}

_mongo_ensure_helm_repo() {
    local repo_name="$1"
    local repo_url="$2"

    if ! helm repo list 2>/dev/null | awk 'NR>1 {print $1}' | grep -Fxq "$repo_name"; then
        log_info "Adding Helm repo $repo_name"
        helm repo add "$repo_name" "$repo_url" >/dev/null
    fi

    helm repo update "$repo_name" >/dev/null 2>&1 || helm repo update >/dev/null
}

# =============================================================================
# Main Deployment Function
# =============================================================================

deploy_mongo_express() {
    _mongo_require_binary aws || return 1
    _mongo_require_binary kubectl || return 1
    _mongo_require_binary helm || return 1

    log_info "Starting mongo-express deployment"

    _mongo_ensure_namespace "$MONGO_EXPRESS_NAMESPACE"
    _mongo_ensure_helm_repo "$MONGO_EXPRESS_HELM_REPO_NAME" "$MONGO_EXPRESS_HELM_REPO_URL"

    # Fetch MongoDB admin password from SSM
    log_info "Fetching MongoDB password from SSM"
    local admin_password
    admin_password=$(_mongo_fetch_ssm_parameter "$MONGO_ROOT_PASSWORD_SSM_PATH")
    
    if [[ -z "$admin_password" ]]; then
        log_error "Failed to get MongoDB password from SSM: $MONGO_ROOT_PASSWORD_SSM_PATH"
        return 1
    fi

    _mongo_apply_secret "$MONGO_EXPRESS_NAMESPACE" "$MONGO_EXPRESS_SECRET" "$admin_password"

    # Deploy via Helm
    log_info "Deploying mongo-express Helm release"
    local chart_ref="$MONGO_EXPRESS_HELM_REPO_NAME/mongo-express"
    
    if ! helm upgrade --install "$MONGO_EXPRESS_RELEASE" "$chart_ref" \
        --namespace "$MONGO_EXPRESS_NAMESPACE" \
        --create-namespace \
        --wait \
        --timeout "$MONGO_EXPRESS_ROLLOUT_TIMEOUT" \
        --set mongodbServer="$MONGO_EXPRESS_MONGODB_HOST" \
        --set mongodbPort="$MONGO_EXPRESS_MONGODB_PORT" \
        --set mongodbEnableAdmin=true \
        --set mongodbAdminUsername=root \
        --set mongodbAdminPassword=dummy-placeholder \
        --set existingSecret="$MONGO_EXPRESS_SECRET" \
        --set existingSecretKeyMongodbAdminPassword=mongodb-admin-password \
        --set basicAuthUsername="" \
        --set basicAuthPassword="" \
        >/dev/null 2>&1; then
        log_error "Helm deployment failed"
        return 1
    fi

    log_success "mongo-express deployed successfully"
    log_info "Access via: kubectl port-forward -n $MONGO_EXPRESS_NAMESPACE svc/$MONGO_EXPRESS_RELEASE 8081:8081"
    
    return 0
}
