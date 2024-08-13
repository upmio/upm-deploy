#!/usr/bin/env bash
set -o nounset
# ##############################################################################
# Globals, settings
# ##############################################################################
FILE_NAME="build"
FILE_VERSION="2.0.3"
BASE_DIR="$(dirname "$(readlink -f "${0}")")"

# ##############################################################################
# common function package
# ##############################################################################
die() {
  local status="${1}"
  shift
  error "$*"
  exit "$status"
}

error() {
  local timestamp
  timestamp="$(date +"%Y-%m-%d %T %N")"
  echo "[${timestamp}] (${FILE_NAME}-${FILE_VERSION})ERR: $* ;"
}

info() {
  local timestamp
  timestamp="$(date +"%Y-%m-%d %T %N")"
  echo "[${timestamp}] (${FILE_NAME}-${FILE_VERSION})INFO: $* ;"
}
# ##############################################################################
# The main() function is called at the action function.
# ##############################################################################
REPO="quay.io"
PROJECT="upmio"
NAME="nacos-server-initdb"
VERSION="v2.4.0"
IMAGE_NAME="${REPO}/${PROJECT}/${NAME}:${VERSION}"

info "Starting build image"

cd "${BASE_DIR}" || die 11 "cd ${BASE_DIR} failed!"
if printenv http_proxy; then
  docker buildx build  --platform linux/amd64,linux/arm64 --build-arg http_proxy="$(printenv http_proxy)" --build-arg https_proxy="$(printenv https_proxy)" -t "${IMAGE_NAME}" . --push || {
    die 12 "build and push docker image(${IMAGE_NAME}) files failed!"
  }
else
  docker buildx build  --platform linux/amd64,linux/arm64 -t "${IMAGE_NAME}" . --push || {
    die 13 "build and push docker image(${IMAGE_NAME}) files failed!"
  }
fi

info "Build image(${IMAGE_NAME}) done !!!"
