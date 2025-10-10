#!/bin/sh

set -e -x

test $# = 2 || exit 1

VERSION="$1"
ABI="$2"

PLATFORM=manylinux2014_x86_64
PYTAG=${ABI/m/}
TAG=${PYTAG}-${ABI}-${PLATFORM}
PYVERD=${ABI:2:1}.${ABI:3}

SCRIPT=`readlink -f "$0"`
SCRIPTPATH=`dirname "$SCRIPT"`
export PATH=/opt/python/${PYTAG}-${ABI}/bin/:$PATH

cd /tmp
#curl -fSsL https://files.salome-platform.org/Salome/medfile/med-${VERSION}.tar.gz | tar xz
curl -fSsL https://files.catbox.moe/zm3to1.gz | tar xz
cd med-${VERSION}

# we cannot link to python libs here
sed -i "s|PYTHON_LIBRARIES|ZZZ|g" python/CMakeLists.txt

sed -i "s|PyEval_CallObject(pclass, pargs)|PyObject_Call(pclass, pargs, NULL)|g" python/med*.i

# mkdir build && cd build
cmake -LAH -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PWD/install \
      -DPYTHON_INCLUDE_DIR=/opt/python/${PYTAG}-${ABI}/include/python${PYVERD} -DPYTHON_LIBRARY=dummy \
      -DPYTHON_EXECUTABLE=/opt/python/${PYTAG}-${ABI}/bin/python \
      -DCMAKE_INSTALL_RPATH="${PWD}/install/lib;/usr/local/lib" -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON \
      -DMEDFILE_BUILD_PYTHON=ON -DMEDFILE_BUILD_TESTS=OFF -DMEDFILE_INSTALL_DOC=OFF \
      .
make install

cd install/lib/python*/site-packages/
rm -rf med/__pycache__

# write metadata
mkdir medfile-${VERSION}.dist-info
sed "s|@PACKAGE_VERSION@|${VERSION}|g" ${SCRIPTPATH}/METADATA.in > medfile-${VERSION}.dist-info/METADATA
python ${SCRIPTPATH}/write_distinfo.py medfile ${VERSION} ${TAG}

# create archive
zip -r medfile-${VERSION}-${TAG}.whl med medfile-${VERSION}.dist-info
auditwheel show medfile-${VERSION}-${TAG}.whl
auditwheel repair medfile-${VERSION}-${TAG}.whl -w /io/wheelhouse/

# test
cd /tmp
pip install medfile --pre --no-index -f /io/wheelhouse
python -c "import med; print('ok')"

