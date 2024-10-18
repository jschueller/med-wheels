#!/bin/sh

set -e -x

test $# = 1 || exit 1

VERSION="$1"
ABI=cp39

PLATFORM=manylinux2014_x86_64
PYTAG=${ABI/m/}
TAG=${PYTAG}-abi3-${PLATFORM}
PYVERD=${ABI:2:1}.${ABI:3}

SCRIPT=`readlink -f "$0"`
SCRIPTPATH=`dirname "$SCRIPT"`
export PATH=/opt/python/${PYTAG}-${ABI}/bin/:$PATH

cd /tmp
curl -fSsL https://www.code-saturne.org/releases/external/med-${VERSION}.tar.gz | tar xz
cd med-${VERSION}*

# we cannot link to python libs here
sed -i "s|PYTHON_LIBRARIES|ZZZ|g" python/CMakeLists.txt

# mkdir build && cd build
cmake -LAH -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PWD/install \
      -DPYTHON_INCLUDE_DIR=/opt/python/${PYTAG}-${ABI}/include/python${PYVERD} -DPYTHON_LIBRARY=dummy \
      -DPYTHON_EXECUTABLE=/opt/python/${PYTAG}-${ABI}/bin/python \
      -DCMAKE_INSTALL_RPATH="${PWD}/install/lib;/usr/local/lib" -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
      -DMEDFILE_BUILD_PYTHON=ON -DMEDFILE_BUILD_TESTS=OFF -DMEDFILE_INSTALL_DOC=OFF \
      -DCMAKE_CXX_FLAGS="-DPy_LIMITED_API=0x03090000" \
      .
make install

cd install/lib/python*/site-packages/
rm -rf med/__pycache__

# write metadata
mkdir salome_med-${VERSION}.dist-info
sed "s|@PACKAGE_VERSION@|${VERSION}|g" ${SCRIPTPATH}/METADATA.in > salome_med-${VERSION}.dist-info/METADATA
python ${SCRIPTPATH}/write_distinfo.py salome_med ${VERSION} ${TAG}

# create archive
zip -r salome_med-${VERSION}-${TAG}.whl med salome_med-${VERSION}.dist-info

auditwheel show salome_med-${VERSION}-${TAG}.whl
auditwheel repair salome_med-${VERSION}-${TAG}.whl -w /io/wheelhouse/

# test
cd /tmp
pip install salome_med --pre --no-index -f /io/wheelhouse
python -c "import med; print('ok')"

