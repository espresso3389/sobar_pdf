#!/bin/bash -eu

# https://pdfium.googlesource.com/pdfium/+/refs/heads/chromium/4147
#LAST_KNOWN_GOOD_COMMIT=3e36f68831431bf497babc74075cd69af5fd9823

scripts_dir=$(cd $(dirname $0) && pwd)
VCPKG_TARGET_TRIPLET=$1
# x64 or x86
GN_ARCH=$2
# static or dll
STATIC_OR_DLL=$3
# Release or Debug
REL_OR_DBG=$4

DEPOT_DIR=$5

export PATH=$DEPOT_DIR:$PATH

IS_SHAREDLIB=false

if [ $REL_OR_DBG = "Release" ]; then
    IS_DEBUG=false
    DEBUG_DIR_SUFFIX=
else
    IS_DEBUG=true
    DEBUG_DIR_SUFFIX=/debug
fi

if [[ $VCPKG_TARGET_TRIPLET == *"osx"* ]]; then
  IS_CLANG=true
else
  IS_CLANG=false
fi

if [ ! -d pdfium/.git/index ]; then
    gclient config -vvv --unmanaged https://pdfium.googlesource.com/pdfium.git
    gclient sync -vvv
fi

cd pdfium
ROOTDIR=$(pwd)
BUILDDIR=$ROOTDIR/out/$VCPKG_TARGET_TRIPLET$DEBUG_DIR_SUFFIX

mkdir -p $BUILDDIR

git reset --hard
git checkout $LAST_KNOWN_GOOD_COMMIT

cat <<EOF > $BUILDDIR/args.gn
is_clang = $IS_CLANG
use_custom_libcxx=false
target_cpu = "$GN_ARCH"
pdf_is_complete_lib = true
pdf_is_standalone = true
is_component_build = $IS_SHAREDLIB
is_debug = $IS_DEBUG
enable_iterator_debugging = $IS_DEBUG
pdf_enable_xfa = false
pdf_enable_v8 = false
# Reduce dependency to GLIBC
#use_glib = false
EOF

gn gen $BUILDDIR
ninja -C $BUILDDIR pdfium
