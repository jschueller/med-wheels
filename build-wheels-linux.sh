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
curl -L https://files.salome-platform.org/Salome/other/med-${VERSION}.tar.gz | tar xz
cd med-${VERSION}_SRC

# we cannot link to python libs here
sed -i "s|PYTHON_LIBRARIES|ZZZ|g" python/CMakeLists.txt

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
mkdir salome_med-${VERSION}.dist-info
sed "s|@PACKAGE_VERSION@|${VERSION}|g" ${SCRIPTPATH}/METADATA.in > salome_med-${VERSION}.dist-info/METADATA
echo -e "Wheel-Version: 1.0" > salome_med-${VERSION}.dist-info/WHEEL
for f in `find med salome_med-${VERSION}.dist-info -type f`; do echo "$f,," >> salome_med-${VERSION}.dist-info/RECORD ; done

# create archive
zip -r salome_med-${VERSION}-${TAG}.whl med salome_med-${VERSION}.dist-info
auditwheel show salome_med-${VERSION}-${TAG}.whl
auditwheel repair salome_med-${VERSION}-${TAG}.whl -w /io/wheelhouse/

# test
cd /tmp
pip install med --pre --no-index -f /io/wheelhouse
python -c "import med; print('ok')"

