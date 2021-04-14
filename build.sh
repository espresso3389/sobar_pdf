#!/bin/bash -e

curDir=$(cd $(dirname $0) && pwd)
cd $curDir

if [ "$1" = "" ]; then
    echo "Usage: $0 x86|x64 [linux|android|osx]"
    exit 1
fi

if [ "$2" = "" ]; then
    targetOS=linux
else
    targetOS=$2
fi

arch=$1
tmpDir=$curDir/.work
cacheDir=$curDir/.cache
outDir=$tmpDir/$arch
distDir=$curDir/dist/$arch
sobarTargetStr=$targetOS-$arch
mkdir -p $cacheDir
mkdir -p $tmpDir

source ./scripts/git_info.sh . Sobar

cmake -S . -B $outDir -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DSOBAR_TARGET_STR=$sobarTargetStr \
    -DSOBAR_REVISION=$SobarRev \
    -DSOBAR_COMMIT=$SobarCommit \
    -DSOBAR_TMP_DIR=$tmpDir \
    -DSOBAR_CACHE_DIR=$cacheDir

cmake --build $outDir

mkdir -p $distDir/include
cp include/sobar.h $distDir/include

libDir=$distDir/lib/linux/$arch
mkdir -p $libDir
cp $tmpDir/$arch/src/libsobar.so $libDir
