#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
: "${IMAGE_PREFIX:?Set IMAGE_PREFIX to the registry and repository prefix}"
: "${IMAGE_TAG:?Set IMAGE_TAG to the commit SHA}"
: "${INGRESS_HOST:?Set INGRESS_HOST to the public DNS name}"
namespace=${NAMESPACE:-test}

kubectl -n "$namespace" rollout status statefulset/postgres --timeout=3m

for service in library-service reservation-service rating-service gateway; do
  helm upgrade --install "$service" helm/app \
    --namespace "$namespace" \
    --values "deploy/values/$service.yaml" \
    --set-string "image.repository=$IMAGE_PREFIX/$service" \
    --set-string "image.tag=$IMAGE_TAG" \
    --set-string "ingress.host=$INGRESS_HOST" \
    --wait --timeout 3m
done
