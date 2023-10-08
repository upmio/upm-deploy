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
UPLOAD_FLAG="${1:-0}"
PROJECT="dbscale"
NAME="nacos-server-initDB"
VERSION="v2.2.3"
IMAGE_NAME="${PROJECT}/${NAME}:${VERSION}"

info "Starting build image"

cd "${BASE_DIR}" || die 11 "cd ${BASE_DIR} failed!"
if printenv http_proxy; then
  docker build --rm=true --network=host -t "${IMAGE_NAME}" --build-arg http_proxy="$(printenv http_proxy)" --build-arg https_proxy="$(printenv https_proxy)" . || {
    die 12 "build docker image(${IMAGE_NAME}) files failed!"
  }
else
  docker build --rm=true --network=host -t "${IMAGE_NAME}" . || {
    die 13 "build docker image(${IMAGE_NAME}) files failed!"
  }
fi

info "Build image(${IMAGE_NAME}) done !!!"

# Get image ID
local_image_id=$(docker images --no-trunc "${IMAGE_NAME}" --format "{{.ID}}" | awk -F: '{print $2}') || die 14 "get docker image(${IMAGE_NAME}) ID failed!"
image_id=$(cat "${BASE_DIR}/IMG_ID")
if [[ "${local_image_id}" != "${image_id}" ]]; then
  info "Starting push image ID"

  echo "${local_image_id}" >"${BASE_DIR}/IMG_ID"
  git add "${BASE_DIR}/IMG_ID" || die 18 "git add ${BASE_DIR}/IMG_ID failed!"
  git commit -m "update ${IMAGE_NAME} IMG_ID" || die 19 "git commit failed!"
  git push || die 15 "git push failed!"

  info "Push image(${IMAGE_NAME}) ID done !!!"
fi

if [[ "${UPLOAD_FLAG}" == 1 ]]; then
  info "Starting upload image(${IMAGE_NAME}) to docker.io/${PROJECT}"

  docker login || die 16 "docker login failed!"
  docker push "${IMAGE_NAME}" || die 17 "docker push failed!"

  info "upload image(${IMAGE_NAME}) to docker.io/${PROJECT} done !!!"
fi
