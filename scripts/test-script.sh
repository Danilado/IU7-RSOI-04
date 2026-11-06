#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
variant=${1:-${VARIANT:-v4}}
deployment=${2:-${DEPLOYMENT_NAME:-rating-service}}
namespace=${3:-${NAMESPACE:-test}}
: "${BASE_URL:?Set BASE_URL to the Ingress URL}"
if [[ "$variant" != v4 ]]; then
  echo "This repository implements v4 (Library System)." >&2
  exit 2
fi

export TZ=UTC
environment=$(mktemp)
restore_rating=false
cleanup() {
  local status=$?
  rm -f "$environment"
  if [[ "$restore_rating" == true ]]; then
    kubectl -n "$namespace" scale deployment "$deployment" --replicas=1 || {
      echo "Could not restore $deployment to one replica" >&2
      exit 1
    }
  fi
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

username="rsoi04-$(date +%s)-$$"
jq --arg url "${BASE_URL%/}" --arg user "$username" '
  (.values[] | select(.key == "baseUrl").value) = $url
  | .values += [{"key": "username", "value": $user, "enabled": true}]
' "$variant/postman/environment.json" > "$environment"

run_folder() {
  newman run "$variant/postman/collection.json" \
    --folder "$1" --bail --timeout-request 5000 \
    --environment "$environment" --export-environment "$environment"
}

rating_url="${BASE_URL%/}/api/v1/rating"
wait_for_rating_status() {
  local expected=$1 attempt status
  for ((attempt=0; attempt<45; attempt++)); do
    status=$(curl -s --max-time 3 -o /dev/null -w '%{http_code}' \
      -H "X-User-Name: $username" "$rating_url") || status=""
    [[ "$status" == "$expected" ]] && return 0
    sleep 1
  done
  echo "Rating endpoint did not return HTTP $expected" >&2
  return 1
}

wait_for_rating_update() {
  local before expected attempt rating
  before=$(jq -er '.values[] | select(.key == "stars").value | tonumber' "$environment")
  expected=$((before + 1))
  for ((attempt=0; attempt<45; attempt++)); do
    rating=$(curl -fsS --max-time 3 -H "X-User-Name: $username" "$rating_url" |
      jq -er '.stars') || rating=""
    [[ "$rating" == "$expected" ]] && return 0
    sleep 1
  done
  echo "Rating did not reach $expected stars" >&2
  return 1
}

scale_rating() {
  local replicas=$1
  echo "=== Scale $deployment to $replicas ==="
  kubectl -n "$namespace" scale deployment "$deployment" --replicas="$replicas"
  if [[ "$replicas" == 0 ]]; then
    wait_for_rating_status 503
  else
    kubectl -n "$namespace" rollout status "deployment/$deployment" --timeout=3m
    wait_for_rating_status 200
  fi
}

wait_for_rating_status 200
run_folder success
restore_rating=true
scale_rating 0
run_folder step1
scale_rating 1
run_folder step2
scale_rating 0
run_folder step3
scale_rating 1
restore_rating=false
wait_for_rating_update
run_folder step4
