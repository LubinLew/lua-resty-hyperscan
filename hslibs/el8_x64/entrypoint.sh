#!/bin/bash

set -ex

HSVER=5.4.0
DST=/install

# https://github.com/intel/hyperscan/releases/
curl -Lso v${HSVER}.tar.gz  https://github.com/intel/hyperscan/archive/refs/tags/v${HSVER}.tar.gz
tar   xf  v${HSVER}.tar.gz

mkdir build
cd    build

# http://intel.github.io/hyperscan/dev-reference/getting_started.html#cmake-configuration
cmake -DCMAKE_BUILD_TYPE=MinSizeRel   \
      -DBUILD_STATIC_AND_SHARED=on    \
      -DCMAKE_INSTALL_PREFIX=${DST}   \
      /hyperscan-${HSVER}

make -j`nproc`
make install