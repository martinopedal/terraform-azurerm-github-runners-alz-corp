#!/bin/bash
set -euo pipefail

# GitHub Actions Runner — Dual-Auth Entrypoint (Org/Repo-Scope + App/PAT Coexistence)
#
# Supports org-level OR repo-level ephemeral runner registration with BOTH GitHub App auth
# (primary) and PAT fallback (safety net). Prevents single-auth-mode stranding (see ADR caj-a1).
#
# Required environment variables:
#   GITHUB_OWNER or ORG_NAME  — GitHub org (e.g., "alz-avm-tf-demo")
#   RUNNER_SCOPE              — "org" (org-level) or "repo" (repo-level)
#   TARGET_REPOS              — Comma-separated repo names (required if RUNNER_SCOPE=repo, e.g., "alz-prod,alz-firewall-ops")
#   RUNNER_LABELS             — Comma-separated labels (e.g., "self-hosted,alz-a1,linux,x64")
#   RUNNER_GROUP              — Runner group name (optional, org-scope only, defaults to "Default")
#   RUNNER_NAME               — Runner name (optional, defaults to hostname)
#   RUNNER_AUTH_MODE          — "auto" (App→PAT fallback), "github_app" (App only), "pat" (PAT only)
#
# GitHub App auth (RUNNER_AUTH_MODE=auto or github_app):
#   APP_ID                    — GitHub App ID (e.g., "3806955")
#   APP_INSTALLATION_ID       — GitHub App installation ID (e.g., "139071845")
#   APP_PRIVATE_KEY           — GitHub App private key (PEM format, can be multiline)
#
# PAT auth (RUNNER_AUTH_MODE=auto fallback or pat):
#   PAT_FALLBACK_ACCESS_TOKEN — Personal Access Token (ghp_* or github_pat_*) with appropriate scope
#
# Design:
# - RUNNER_AUTH_MODE=auto (default): Mint GitHub App installation token first. If App path
#   is unavailable/fails (missing vars, mint error, 401), fall back to PAT_FALLBACK_ACCESS_TOKEN.
# - RUNNER_AUTH_MODE=github_app: App-only (no fallback). Exit if App mint fails.
# - RUNNER_AUTH_MODE=pat: PAT-only. Use PAT_FALLBACK_ACCESS_TOKEN directly.
# - RUNNER_SCOPE=repo: Iterates TARGET_REPOS, finds one with queued job matching labels, registers there.
# - RUNNER_SCOPE=org: Registers at org level (requires org self-hosted-runners write permission).
#
# Mirrors entrypoint-deployed.sh's PAT_FALLBACK_ACCESS_TOKEN + TARGET_REPOS pattern. Makes
# dual-auth + dual-scope the standard for all pools. Prevents caj-a1 stranding scenario.
#
# Authority: .squad/decisions/inbox/copilot-directive-runner-dual-auth-2026-06-09.md

# --- Env var normalization ---
ORG_NAME="${ORG_NAME:-${GITHUB_OWNER:-}}"
RUNNER_SCOPE="${RUNNER_SCOPE:-org}"
TARGET_REPOS="${TARGET_REPOS:-}"
RUNNER_NAME="${RUNNER_NAME:-$(hostname)}"
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,linux,x64}"
RUNNER_GROUP="${RUNNER_GROUP:-Default}"
RUNNER_AUTH_MODE="${RUNNER_AUTH_MODE:-auto}"

APP_ID="${APP_ID:-}"
APP_INSTALLATION_ID="${APP_INSTALLATION_ID:-}"
APP_PRIVATE_KEY="${APP_PRIVATE_KEY:-}"
PAT_FALLBACK_ACCESS_TOKEN="${PAT_FALLBACK_ACCESS_TOKEN:-}"

if [ -z "${ORG_NAME}" ]; then
  echo "❌ ORG_NAME or GITHUB_OWNER is required" >&2
  exit 1
fi

if [ "${RUNNER_SCOPE}" = "repo" ] && [ -z "${TARGET_REPOS}" ]; then
  echo "❌ RUNNER_SCOPE=repo requires TARGET_REPOS (comma-separated repo names)" >&2
  exit 1
fi

# --- GitHub API helpers ---
GH_API="https://api.github.com"
ACCEPT_HEADER="Accept: application/vnd.github+json"
API_VERSION_HEADER="X-GitHub-Api-Version: 2022-11-28"

b64enc() {
  openssl base64 -A | tr -d '=' | tr '/+' '_-' | tr -d '\n'
}

generate_app_jwt() {
  local now iat exp header payload header_b64 payload_b64 signature private_key_clean

  now=$(date +%s)
  iat=$((now - 60))
  exp=$((now + 540)) # < 10 minute ceiling per GitHub docs
  header='{"typ":"JWT","alg":"RS256"}'
  payload=$(jq -cn --arg iss "${APP_ID}" --argjson iat "${iat}" --argjson exp "${exp}" '{iat:$iat,exp:$exp,iss:$iss}')
  header_b64=$(printf '%s' "${header}" | b64enc)
  payload_b64=$(printf '%s' "${payload}" | b64enc)

  private_key_clean=$(printf '%s' "${APP_PRIVATE_KEY}" | tr -d '\r')
  signature=$(printf '%s' "${header_b64}.${payload_b64}" | openssl dgst -binary -sha256 -sign <(printf '%s' "${private_key_clean}") | b64enc)

  printf '%s.%s.%s' "${header_b64}" "${payload_b64}" "${signature}"
}

mint_installation_access_token() {
  local jwt
  jwt=$(generate_app_jwt 2>/dev/null || echo "")
  
  if [ -z "${jwt}" ]; then
    echo "" # JWT build failed
    return 1
  fi

  local response http_code token
  response=$(curl -fsSL -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer ${jwt}" \
    -H "${ACCEPT_HEADER}" \
    -H "${API_VERSION_HEADER}" \
    "${GH_API}/app/installations/${APP_INSTALLATION_ID}/access_tokens" 2>/dev/null || echo -e "\n000")
  
  http_code=$(echo "${response}" | tail -n1)
  token=$(echo "${response}" | head -n -1 | jq -r '.token // empty' 2>/dev/null || echo "")
  
  if [ "${http_code}" -eq 201 ] && [ -n "${token}" ]; then
    printf '%s' "${token}"
    return 0
  else
    echo "" # Mint failed
    return 1
  fi
}

# --- Auth mode selection ---
declare API_TOKEN=""
declare AUTH_METHOD_USED=""

try_app_auth() {
  if [ -z "${APP_ID}" ] || [ -z "${APP_INSTALLATION_ID}" ] || [ -z "${APP_PRIVATE_KEY}" ]; then
    echo "⚠️  GitHub App credentials incomplete (APP_ID, APP_INSTALLATION_ID, or APP_PRIVATE_KEY missing)." >&2
    return 1
  fi

  echo "🔐 Attempting GitHub App installation token mint (App ID: ${APP_ID}, Installation: ${APP_INSTALLATION_ID})..." >&2
  local token
  token=$(mint_installation_access_token || echo "")
  
  if [ -n "${token}" ]; then
    API_TOKEN="${token}"
    AUTH_METHOD_USED="github_app"
    echo "✅ GitHub App auth successful" >&2
    return 0
  else
    echo "❌ GitHub App token mint failed" >&2
    return 1
  fi
}

try_pat_fallback() {
  if [ -z "${PAT_FALLBACK_ACCESS_TOKEN}" ]; then
    echo "❌ PAT_FALLBACK_ACCESS_TOKEN not set" >&2
    return 1
  fi

  if [[ ! "${PAT_FALLBACK_ACCESS_TOKEN}" =~ ^(ghp_|github_pat_) ]]; then
    echo "❌ PAT_FALLBACK_ACCESS_TOKEN does not look like a valid PAT (must start with ghp_ or github_pat_)" >&2
    return 1
  fi

  echo "🔑 Using PAT fallback auth..." >&2
  API_TOKEN="${PAT_FALLBACK_ACCESS_TOKEN}"
  AUTH_METHOD_USED="pat_fallback"
  echo "✅ PAT fallback auth active" >&2
  return 0
}

case "${RUNNER_AUTH_MODE}" in
  github_app)
    if ! try_app_auth; then
      echo "❌ RUNNER_AUTH_MODE=github_app but App auth failed. No fallback allowed in this mode." >&2
      exit 1
    fi
    ;;
  pat)
    if ! try_pat_fallback; then
      echo "❌ RUNNER_AUTH_MODE=pat but PAT fallback is unavailable." >&2
      exit 1
    fi
    ;;
  auto)
    if ! try_app_auth; then
      echo "⚠️  GitHub App auth unavailable. Falling back to PAT..." >&2
      if ! try_pat_fallback; then
        echo "❌ Both GitHub App and PAT fallback failed. No usable auth available." >&2
        exit 1
      fi
    fi
    ;;
  *)
    echo "❌ RUNNER_AUTH_MODE=${RUNNER_AUTH_MODE} is not supported. Use 'auto', 'github_app', or 'pat'." >&2
    exit 1
    ;;
esac

if [ -z "${API_TOKEN}" ]; then
  echo "❌ No API token available after auth selection." >&2
  exit 1
fi

echo "🎯 Dual-Auth ephemeral runner"
echo "   Owner:      ${ORG_NAME}"
echo "   Scope:      ${RUNNER_SCOPE}"
echo "   Name:       ${RUNNER_NAME}"
echo "   Labels:     ${RUNNER_LABELS}"
if [ "${RUNNER_SCOPE}" = "org" ]; then
  echo "   Group:      ${RUNNER_GROUP}"
else
  echo "   Repos:      ${TARGET_REPOS}"
fi
echo "   Auth:       ${AUTH_METHOD_USED}"

# --- Repo-scope: Find a repo with queued job matching labels ---
if [ "${RUNNER_SCOPE}" = "repo" ]; then
  # Build non-default label filter (same pattern as entrypoint-deployed.sh)
  IFS=',' read -ra raw_labels <<< "${RUNNER_LABELS}"
  declare -a MATCH_LABELS=()
  for label in "${raw_labels[@]}"; do
    trimmed=$(echo "${label}" | xargs)
    case "${trimmed,,}" in
      ""|self-hosted|linux|x64|windows|arm64) continue ;;
    esac
    MATCH_LABELS+=("${trimmed}")
  done
  
  if [ ${#MATCH_LABELS[@]} -eq 0 ]; then
    MATCH_LABELS=("alz-a1")  # Default fallback
  fi
  
  LABELS_JSON=$(printf '%s\n' "${MATCH_LABELS[@]}" | jq -R . | jq -s .)
  echo "   Matching labels: ${MATCH_LABELS[*]}"
  
  IFS=',' read -ra REPOS <<< "${TARGET_REPOS}"
  SELECTED_REPO=""
  
  for r in "${REPOS[@]}"; do
    r="$(echo "${r}" | xargs)"
    [ -z "${r}" ] && continue
    
    RUNS_JSON=$(curl -fsSL \
      -H "Authorization: Bearer ${API_TOKEN}" \
      -H "${ACCEPT_HEADER}" \
      -H "${API_VERSION_HEADER}" \
      "${GH_API}/repos/${ORG_NAME}/${r}/actions/runs?status=queued&per_page=10" 2>/dev/null || echo '{}')
    
    RUN_IDS=$(echo "${RUNS_JSON}" | jq -r '.workflow_runs[]?.id // empty')
    MATCHED=0
    
    for run_id in ${RUN_IDS}; do
      JOBS_JSON=$(curl -fsSL \
        -H "Authorization: Bearer ${API_TOKEN}" \
        -H "${ACCEPT_HEADER}" \
        -H "${API_VERSION_HEADER}" \
        "${GH_API}/repos/${ORG_NAME}/${r}/actions/runs/${run_id}/jobs" 2>/dev/null || echo '{}')
      
      HIT=$(echo "${JOBS_JSON}" | jq -r --argjson wanted "${LABELS_JSON}" '
        .jobs[]?
        | select(.status == "queued" or .status == "in_progress")
        | select((.labels // []) as $jobLabels | any($wanted[]; $jobLabels | index(.)))
        | .id' | head -n1)
      
      if [ -n "${HIT}" ]; then
        MATCHED=1
        break
      fi
    done
    
    if [ "${MATCHED}" -eq 1 ]; then
      SELECTED_REPO="${r}"
      echo "   ✅ Repo with matching queued job: ${SELECTED_REPO}"
      break
    fi
  done
  
  if [ -z "${SELECTED_REPO}" ]; then
    echo "ℹ️  No queued jobs matched labels [${MATCH_LABELS[*]}] across ${#REPOS[@]} repos — exiting without registration."
    echo "   KEDA will retry on the next poll if a job is genuinely queued."
    exit 0
  fi
  
  REG_URL="https://github.com/${ORG_NAME}/${SELECTED_REPO}"
  API_TOKEN_PATH="repos/${ORG_NAME}/${SELECTED_REPO}/actions/runners"
  SUFFIX="$(echo "${SELECTED_REPO}" | sha256sum | cut -c1-6)-$RANDOM"
  RUNNER_NAME="${RUNNER_NAME}-${SUFFIX}"
else
  # Org-scope registration
  REG_URL="https://github.com/${ORG_NAME}"
  API_TOKEN_PATH="orgs/${ORG_NAME}/actions/runners"
fi

# --- Fetch registration token ---
echo "🔑 Requesting registration token (${RUNNER_SCOPE}-scope)..."
REG_TOKEN=$(curl -fsSL -X POST \
  -H "Authorization: Bearer ${API_TOKEN}" \
  -H "${ACCEPT_HEADER}" \
  -H "${API_VERSION_HEADER}" \
  "${GH_API}/${API_TOKEN_PATH}/registration-token" \
  | jq -r '.token // empty')

if [ -z "${REG_TOKEN}" ]; then
  echo "❌ Failed to create ${RUNNER_SCOPE}-level registration token." >&2
  exit 1
fi
echo "✅ Registration token acquired (60min TTL)"

# --- Configure runner (ephemeral = auto-deregister after one job) ---
if [ "${RUNNER_SCOPE}" = "org" ]; then
  ./config.sh \
    --url "${REG_URL}" \
    --token "${REG_TOKEN}" \
    --name "${RUNNER_NAME}" \
    --labels "${RUNNER_LABELS}" \
    --runnergroup "${RUNNER_GROUP}" \
    --ephemeral \
    --unattended \
    --replace \
    --disableupdate
else
  ./config.sh \
    --url "${REG_URL}" \
    --token "${REG_TOKEN}" \
    --name "${RUNNER_NAME}" \
    --labels "${RUNNER_LABELS}" \
    --ephemeral \
    --unattended \
    --replace \
    --disableupdate
fi

# --- Trap SIGTERM/SIGINT for graceful shutdown ---
cleanup() {
  echo "⏹️  Received shutdown signal, removing runner..."
  
  # Refresh token for cleanup if using App auth (installation tokens are short-lived)
  if [ "${AUTH_METHOD_USED}" = "github_app" ]; then
    local refreshed
    refreshed=$(mint_installation_access_token 2>/dev/null || echo "")
    if [ -n "${refreshed}" ]; then
      API_TOKEN="${refreshed}"
    fi
  fi
  
  REMOVE_TOKEN=$(curl -fsSL -X POST \
    -H "Authorization: Bearer ${API_TOKEN}" \
    -H "${ACCEPT_HEADER}" \
    -H "${API_VERSION_HEADER}" \
    "${GH_API}/${API_TOKEN_PATH}/remove-token" \
    | jq -r '.token // empty' || true)
  
  [ -n "${REMOVE_TOKEN}" ] && ./config.sh remove --token "${REMOVE_TOKEN}" || true
}
trap cleanup SIGTERM SIGINT EXIT

# --- Run the runner (blocks until job completes, then exits due to --ephemeral) ---
echo "✅ Runner configured. Waiting for job..."
./run.sh &
wait $!
