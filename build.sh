#!/usr/bin/env bash
set -u
ARCH=${1:-amd64}

if [ "$ARCH" == "amd64" ]; then
    PACKAGE_ARCH=amd64
    TRIPLET=x86_64-linux-gnu
elif [ "$ARCH" == "arm64v8" ]; then
    PACKAGE_ARCH=arm64
    TRIPLET=aarch64-linux-gnu
elif [ "$ARCH" == "arm32v7" ]; then
    PACKAGE_ARCH=armhf
    TRIPLET=armhf-linux-gnueabi
fi

set -x
docker image build \
    --build-arg ARCH=$ARCH \
    --build-arg PACKAGE_ARCH=$PACKAGE_ARCH \
    --build-arg TRIPLET=$TRIPLET \
    -t crossenv_example:$ARCH .
