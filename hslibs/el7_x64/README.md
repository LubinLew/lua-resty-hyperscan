# Build HyperScan on CentOS 7

Just run the script blow.

```bash
#!/usr/bin/bash

HS_VER=5.4.0
BOOST_VER=1.73.0

yum -y install ragel cmake gcc gcc-c++

mkdir hs_build
cd hs_build

wget https://github.com/intel/hyperscan/archive/v${HS_VER}.tar.gz
tar xf v${HS_VER}.tar.gz

BOOST_FOLDER_NAME=`echo ${BOOST_VER} | sed 's/\./_/g'`
wget https://dl.bintray.com/boostorg/release/${BOOST_VER}/source/boost_${BOOST_FOLDER_NAME}.tar.gz
tar xf boost_${BOOST_FOLDER_NAME}.tar.gz

mkdir build
cd build

cmake -DCMAKE_BUILD_TYPE=MinSizeRel   \
      -DBUILD_SHARED_LIBS=on          \
      -DBOOST_ROOT=../boost_${BOOST_FOLDER_NAME}    \
          ../hyperscan-${HS_VER}

# 8 = 4 cores x 2
make -j8 

# show result
ls -lh  lib
```
