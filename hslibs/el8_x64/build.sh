#!/usr/bin/env bash

set -ex

DOCKER=hyperscan_builder:centos8
CURPATH="$( cd $(dirname $0) ; pwd -P )"

rm   -rf ${CURPATH}/install
mkdir -p ${CURPATH}/install


docker build -t ${DOCKER} .

docker run --rm -t -v ${CURPATH}/install:/install:Z ${DOCKER}

# PKG_CONFIG_PATH=${CURPATH}/install/lib64/pkgconfig/
sed -i "s#/install#${CURPATH}/install#g"  ${CURPATH}/install/lib64/pkgconfig/libhs.pc
