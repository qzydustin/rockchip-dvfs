#!/bin/sh
# Build px30_dmc_dbg.ko against a ROCKNIX build tree, in the ROCKNIX build container:
# build-module.sh <rocknix checkout> [build.ROCKNIX-RK3326.aarch64]
set -e
ROCKNIX=$(cd "${1:?rocknix checkout}" && pwd)
BUILD=${2:-build.ROCKNIX-RK3326.aarch64}
KDIR=$(ls -d "$ROCKNIX/$BUILD"/build/linux-*/ | head -1)
TC="$ROCKNIX/$BUILD/toolchain/bin"
HERE=$(cd "$(dirname "$0")" && pwd)
case "$HERE" in "$ROCKNIX"/*) ;; *) echo "copy this directory somewhere under $ROCKNIX first (the container only sees that tree)"; exit 1;; esac
docker run --rm --user "$(id -u):$(id -g)" -v "$ROCKNIX:$ROCKNIX" -w "$ROCKNIX" ghcr.io/rocknix/rocknix-build:latest \
  bash -c "export PATH=$TC:\$PATH; make -C $KDIR M=$HERE ARCH=arm64 CROSS_COMPILE=aarch64-rocknix-linux-gnu- HOSTCC=$TC/host-gcc HOSTCXX=$TC/host-g++ modules"
ls -la "$HERE"/px30_dmc_dbg.ko
