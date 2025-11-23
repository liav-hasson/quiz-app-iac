#!/bin/bash
# mongodb-tools.sh
# Helper utilities for ad-hoc MongoDB tooling (e.g., mongo-express)
# Sourced by project-utils.sh to provision debugging aides on demand.

# This helper expects config-loader.sh and logging-helpers.sh to be sourced first.

mongo_tools_require_binary() {
    local bin="$1"
    if ! command -v "$bin" >/dev/null 2>&1; then
        log_error "Required command '$bin' not found in PATH"
        return 1
    fi
}

mongo_tools_ensure_namespace() {
    local namespace="$1"
    if ! kubectl get namespace "$namespace" >/dev/null 2>&1; then
        log_message "Creating namespace $namespace for tooling"
        kubectl create namespace "$namespace" >/dev/null
    fi
}

mongo_tools_fetch_ssm_parameter() {
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

mongo_tools_generate_secret() {
    # 32 bytes of entropy encoded as hex keeps Helm values simple.
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -hex 32
    else
        # Fallback to Python if OpenSSL is unavailable.
        python3 - <<'PY'
import secrets
print(secrets.token_hex(32))
PY
    fi
}

mongo_tools_get_secret_value() {
    local namespace="$1"
    local secret_name="$2"
    local key="$3"

    local encoded decoded=""
    encoded=$(kubectl get secret "$secret_name" -n "$namespace" -o "jsonpath={.data.$key}" 2>/dev/null || true)
    if [[ -n "$encoded" ]]; then
        if decoded=$(printf '%s' "$encoded" | base64 --decode 2>/dev/null); then
            printf '%s' "$decoded"
        elif decoded=$(printf '%s' "$encoded" | base64 -d 2>/dev/null); then
            printf '%s' "$decoded"
        fi
    fi
}

mongo_tools_apply_secret() {
    local namespace="$1"
    local secret_name="$2"
    local admin_password="$3"

    local existing_cookie existing_session
    existing_cookie=$(mongo_tools_get_secret_value "$namespace" "$secret_name" "site-cookie-secret") || true
    existing_session=$(mongo_tools_get_secret_value "$namespace" "$secret_name" "site-session-secret") || true

    local cookie_secret="${existing_cookie:-$(mongo_tools_generate_secret)}"
    local session_secret="${existing_session:-$(mongo_tools_generate_secret)}"

    log_message "Reconciling secret $secret_name in namespace $namespace"

    kubectl -n "$namespace" create secret generic "$secret_name" \
        --from-literal=mongodb-admin-password="$admin_password" \
        --from-literal=site-cookie-secret="$cookie_secret" \
        --from-literal=site-session-secret="$session_secret" \
        --dry-run=client -o yaml | kubectl apply -f - >/dev/null
}

mongo_tools_ensure_helm_repo() {
    local repo_name="$1"
    local repo_url="$2"

    if ! helm repo list 2>/dev/null | awk 'NR>1 {print $1}' | grep -Fxq "$repo_name"; then
        log_message "Adding Helm repo $repo_name ($repo_url)"
        helm repo add "$repo_name" "$repo_url" >/dev/null
    fi

    log_message "Updating Helm repo $repo_name"
    helm repo update "$repo_name" >/dev/null
}

mongo_tools_deploy_mongo_express() {
    mongo_tools_require_binary aws || return 1
    mongo_tools_require_binary kubectl || return 1
    mongo_tools_require_binary helm || return 1

    local namespace="${MONGO_EXPRESS_NAMESPACE:-db-tools}"
    local release="${MONGO_EXPRESS_RELEASE:-mongo-express}"
    local secret_name="${MONGO_EXPRESS_SECRET:-mongo-express-credentials}"
    local repo_name="${MONGO_EXPRESS_HELM_REPO_NAME:-cowboysysop}"
    local repo_url="${MONGO_EXPRESS_HELM_REPO_URL:-https://cowboysysop.github.io/charts}"
    local chart_ref="${MONGO_EXPRESS_CHART:-$repo_name/mongo-express}"
    local mongodb_host="${MONGO_EXPRESS_MONGODB_HOST:-mongodb.mongodb.svc.cluster.local}"
    local mongodb_port="${MONGO_EXPRESS_MONGODB_PORT:-27017}"
    local base_url="${MONGO_EXPRESS_BASEURL:-/}"
    local ssm_parameter="${MONGO_ROOT_PASSWORD_SSM_PATH:-/quiz-app/mongodb/root-password}"
    local wait_timeout="${MONGO_EXPRESS_ROLLOUT_TIMEOUT:-180s}"

    log_message "Starting mongo-express helper in namespace $namespace"

    mongo_tools_ensure_namespace "$namespace"
    mongo_tools_ensure_helm_repo "$repo_name" "$repo_url"

    log_message "Fetching MongoDB admin password from SSM parameter $ssm_parameter"
    local admin_password
    if ! admin_password=$(mongo_tools_fetch_ssm_parameter "$ssm_parameter"); then
        log_error "Failed to read MongoDB password from SSM parameter $ssm_parameter"
        return 1
    fi

    if [[ -z "$admin_password" ]]; then
        log_error "MongoDB password from $ssm_parameter is empty"
        return 1
    fi

    mongo_tools_apply_secret "$namespace" "$secret_name" "$admin_password"

    log_message "Deploying Helm release $release ($chart_ref)"
    if ! helm upgrade --install "$release" "$chart_ref" \
        --namespace "$namespace" \
        --create-namespace \
        --wait \
        --timeout "$wait_timeout" \
        --set mongodbServer="$mongodb_host" \
        --set mongodbPort="$mongodb_port" \
        --set mongodbEnableAdmin=true \
        --set mongodbAdminUsername=root \
        --set mongodbAdminPassword=dummy-placeholder \
        --set existingSecret="$secret_name" \
        --set existingSecretKeyMongodbAdminPassword=mongodb-admin-password \
        --set siteBaseUrl="$base_url" \
        --set service.type=ClusterIP; then
        log_error "Helm upgrade for $release failed"
        return 1
    fi

    log_message "Waiting for Deployment/$release rollout in namespace $namespace"
    if ! kubectl rollout status deployment/"$release" -n "$namespace" --timeout "$wait_timeout" >/dev/null; then
        log_warning "Deployment $release did not report Ready inside $wait_timeout"
    fi

    echo ""
    echo "Mongo Express is ready in namespace '$namespace'."
    echo "Port-forward locally with:"
    echo "  kubectl -n $namespace port-forward deploy/$release 8081:8081"
    echo "Then open http://127.0.0.1:8081/"
    echo ""
}
