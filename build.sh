#!/bin/bash -e

curDir=$(cd $(dirname $0) && pwd)
cd $curDir

if [ "$2" = "" ]; then
    echo "Usage: $0 x86|x64|arm|arm64 linux|android|mac|ios"
    exit 1
fi

arch=$1
targetOS=$2
tmpDir=$curDir/.work
cacheDir=$curDir/.cache
outDir=$tmpDir/$arch
distDir=$curDir/dist/$arch
sobarTargetStr=$targetOS-$arch
mkdir -p $cacheDir
mkdir -p $tmpDir

if [ "$arch" == "x64" ]; then
  arch_full=x86_64
else
  arch_full=$arch
fi

if [[ "$targetOS" == "mac" || "$targetOS" == "ios" ]]; then
  ext=dylib
else
  ext=so
fi

if [[ "$targetOS" == "ios" ]]; then
  IOS_DEFINITIONS=-DCMAKE_TOOLCHAIN_FILE=$curDir/scripts/ios-cmake/toolchain/iOS.cmake
fi

source ./scripts/git_info.sh . Sobar

cmake -S . -B $outDir -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DSOBAR_TARGET_STR=$sobarTargetStr \
    -DSOBAR_REVISION=$SobarRev \
    -DSOBAR_COMMIT=$SobarCommit \
    -DSOBAR_TMP_DIR=$tmpDir \
    -DSOBAR_CACHE_DIR=$cacheDir \
    -DCMAKE_OSX_ARCHITECTURES=$arch_full \
    $IOS_DEFINITIONS

cmake --build $outDir

mkdir -p $distDir/include
cp include/sobar.h $distDir/include

libDir=$distDir/lib/linux/$arch
mkdir -p $libDir
cp $tmpDir/$arch/src/libsobar.$ext $libDir
