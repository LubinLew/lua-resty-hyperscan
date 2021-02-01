# Build HyperScan on CentOS 8

Just run the script blow.

```bash
#!/usr/bin/bash

HS_VER=5.4.0

yum -y install ragel cmake boost-devel gcc-c++

mkdir hs_build
cd hs_build

wget https://github.com/intel/hyperscan/archive/v${HS_VER}.tar.gz
tar xf v${HS_VER}.tar.gz


mkdir build
cd build

cmake -DCMAKE_BUILD_TYPE=MinSizeRel   \
      -DBUILD_SHARED_LIBS=on          \
          ../hyperscan-${HS_VER}

# 8 = 4 cores x 2
make -j8 

# show result
ls -lh  lib
```
