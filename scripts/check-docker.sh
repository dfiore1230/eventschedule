#!/usr/bin/env bash
set -euo pipefail

if docker info >/dev/null 2>&1; then
  echo "Docker daemon is running."
  docker version
  exit 0
else
  echo "Docker daemon not available. Please start Docker Desktop or your Docker daemon and try again."
  exit 2
fi
