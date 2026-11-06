#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
: "${IMAGE_PREFIX:?Set IMAGE_PREFIX to the registry and repository prefix}"
: "${IMAGE_TAG:?Set IMAGE_TAG to the commit SHA}"

for service in library-service reservation-service rating-service gateway; do
  image="$IMAGE_PREFIX/$service:$IMAGE_TAG"
  docker build --tag "$image" "$service"
  docker push "$image"
done
