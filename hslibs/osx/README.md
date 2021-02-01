# Build HyperScan on MacOS

You SHOULD install [Clang](https://www.ics.uci.edu/~pattis/common/handouts/macclion/clang.html) first. Then run the script blow.

>  Note: Hyperscan is not support ['fat runtime'](http://intel.github.io/hyperscan/dev-reference/getting_started.html#fat-runtime) on MacOS, so the libaray you build may not work on another MacOS.

```bash
#!/bin/zsh

HS_VER=5.4.0
BOOST_VER=1.73.0

brew install ragel cmake

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
ls -lh lib
```
