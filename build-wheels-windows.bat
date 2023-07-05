@echo on
set VERSION=%1%
set ABI=%2%
set PY_VER=%ABI:~2,1%.%ABI:~3%

echo "ABI=%ABI%"
echo "PY_VER=%PY_VER%"
echo "PATH=%PATH%"

set PYTHON_ROOT=%pythonLocation%
python --version

:: hdf5
git clone --depth 1 -b hdf5-1_10_3 https://github.com/HDFGroup/hdf5.git
cmake -LAH -S hdf5 -B build_hdf5 -DCMAKE_INSTALL_PREFIX=C:/Libraries/hdf5 -DBUILD_TESTING=OFF -DHDF5_BUILD_TOOLS=OFF -DHDF5_BUILD_EXAMPLES=OFF
cmake --build build_hdf5 --config Release --target install

:: med
curl -LO https://files.salome-platform.org/Salome/other/med-%VERSION%.tar.gz
7z x med-%VERSION%.tar.gz > nul
dir /p
7z x med-%VERSION%.tar > nul
dir /p
cmake -LAH -S med-%VERSION%_SRC -B build_med -DCMAKE_INSTALL_PREFIX=C:/Libraries/med -DHDF5_ROOT_DIR=C:/Libraries/hdf5 ^
  -DMEDFILE_BUILD_TESTS=OFF -DMEDFILE_INSTALL_DOC=OFF -DMEDFILE_BUILD_PYTHON=ON ^
  -DPYTHON_LIBRARY=%PYTHON_ROOT%\libs\python%ABI:~2%.lib -DPYTHON_INCLUDE_DIR=%PYTHON_ROOT%\include ^
  -DPYTHON_EXECUTABLE=%PYTHON_ROOT%\python.exe
cmake --build build_med --config Release --target install

:: build wheel
xcopy /y C:\Libraries\hdf5\bin\hdf5.dll C:\Libraries\med\lib\python%PY_VER%\site-packages\med
xcopy /y C:\Libraries\med\lib\medC.dll C:\Libraries\med\lib\python%PY_VER%\site-packages\med

curl -LO https://github.com/lucasg/Dependencies/releases/download/v1.11.1/Dependencies_x64_Release_.without.peview.exe.zip
7z x Dependencies_x64_Release_.without.peview.exe.zip
Dependencies.exe -modules C:\Libraries\med\lib\python%PY_VER%\site-packages\med\_medenum.pyd

pushd C:\Libraries\med\lib\python%PY_VER%\site-packages
mkdir salome_med-%VERSION%.dist-info
sed "s|@PACKAGE_VERSION@|%VERSION%|g" %GITHUB_WORKSPACE%\METADATA.in > salome_med-%VERSION%.dist-info\METADATA
type salome_med-%VERSION%.dist-info\METADATA
echo Wheel-Version: 1.0 > salome_med-%VERSION%.dist-info\WHEEL
echo salome_med-%VERSION%.dist-info\RECORD,, > salome_med-%VERSION%.dist-info\RECORD
mkdir %GITHUB_WORKSPACE%\wheelhouse
7z a -tzip %GITHUB_WORKSPACE%\wheelhouse\salome_med-%VERSION%-%ABI%-%ABI%-win_amd64.whl med salome_med-%VERSION%.dist-info
pip install %GITHUB_WORKSPACE%\wheelhouse\salome_med-%VERSION%-%ABI%-%ABI%-win_amd64.whl
pushd %GITHUB_WORKSPACE%
python -c "import med; print(42)"
