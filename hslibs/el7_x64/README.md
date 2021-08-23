HS_VER=5.4.0
BOOST_VER=1.77.0

yum -y install epel-release # for ragel
yum -y install ragel cmake gcc gcc-c++ bzip2

mkdir hs_build
cd hs_build

curl https://codeload.github.com/intel/hyperscan/tar.gz/refs/tags/v${HS_VER} -ko v${HS_VER}.tar.gz || exit 1
tar xf v${HS_VER}.tar.gz

BOOST_FOLDER_NAME=`echo ${BOOST_VER} | sed 's/\./_/g'`
curl "https://boostorg.jfrog.io/ui/api/v1/download?repoKey=main&path=release%252F${BOOST_VER}%252Fsource%252Fboost_${BOOST_FOLDER_NAME}.tar.bz2" -L -o boost-${BOOST_VER}.tar.bz2 || exit 1
tar xf boost-${BOOST_VER}.tar.bz2

mkdir build
cd build

cmake -DCMAKE_BUILD_TYPE=MinSizeRel   \
      -DBUILD_SHARED_LIBS=on          \
      -DBOOST_ROOT=../boost_${BOOST_FOLDER_NAME}    \
          ../hyperscan-${HS_VER} || exit 1

# 8 = 4 cores x 2
make -j8 || exit 1

# show result
ls -lh  lib
