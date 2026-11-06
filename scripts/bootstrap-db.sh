#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
namespace=${NAMESPACE:-test}
kubectl get namespace "$namespace" >/dev/null

if [[ -z $(kubectl -n "$namespace" get secret rsoi04-db --ignore-not-found -o name) ]]; then
  umask 077
  credentials=$(mktemp)
  trap 'rm -f "$credentials"' EXIT
  library_password=$(openssl rand -hex 24)
  reservation_password=$(openssl rand -hex 24)
  rating_password=$(openssl rand -hex 24)

  cat > "$credentials" <<ENV
POSTGRES_PASSWORD=$(openssl rand -hex 24)
LIBRARY_PASSWORD=$library_password
RESERVATION_PASSWORD=$reservation_password
RATING_PASSWORD=$rating_password
LIBRARY_DATABASE_URL=postgres://library_app:$library_password@postgres:5432/libraries
RESERVATION_DATABASE_URL=postgres://reservation_app:$reservation_password@postgres:5432/reservations
RATING_DATABASE_URL=postgres://rating_app:$rating_password@postgres:5432/ratings
ENV
  kubectl -n "$namespace" create secret generic rsoi04-db --from-env-file="$credentials"
fi

kubectl -n "$namespace" apply -k deploy/postgres
kubectl -n "$namespace" rollout status statefulset/postgres --timeout=3m
