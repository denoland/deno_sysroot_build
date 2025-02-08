#!/bin/bash
set -euxo pipefail

# This script runs inside of the docker container to build a pristine sysroot.

DISTRO=bionic

# Note: for earlier versions of Ubuntu "aarch64" is considered a port and requires a different package
# source. This may change for future distros.
declare -A DISTRO_SOURCES=(
  ["aarch64"]=http://ports.ubuntu.com/
  ["x86_64"]=http://azure.archive.ubuntu.com/ubuntu
)
ARCH=$(uname -m)
DISTRO_SOURCE="${DISTRO_SOURCES[${ARCH}]}"

echo "Building ${ARCH} sysroot from ${DISTRO} at ${DISTRO_SOURCE}..."

# Note that this can fail if you have Rosetta enabled on Apple Silicon
# This can be disabled from "Features in Development" page
debootstrap \
  --include=ca-certificates,curl,file,libc6-dev,make \
  --no-merged-usr --variant=buildd $DISTRO /sysroot \
  $DISTRO_SOURCE || (
  cat /sysroot/debootstrap/debootstrap.log &&
    echo "deboostrap failed. If building on Apple Silicon, make sure Rosetta is disabled." &&
    exit 1
)
