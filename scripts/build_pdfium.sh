#!/bin/bash -e

# https://pdfium.googlesource.com/pdfium/+/refs/heads/chromium/4147
# LAST_KNOWN_GOOD_COMMIT=235683e8c00b558fd4ab484b577233ccfeca6a63

scripts_dir=$(cd $(dirname $0) && pwd)
# linux, android, mac, ios
SOBAR_TARGET_STR=$1
# x64, x86, ...
GN_ARCH=$2
# static or dll
STATIC_OR_DLL=$3
# Release or Debug
REL_OR_DBG=$4
DEPOT_DIR=$5
WORK_DIR=$6
TARGET_OS=$7

export PATH=$DEPOT_DIR:$PATH

IS_SHAREDLIB=false

if [ "$REL_OR_DBG" = "Release" ]; then
    IS_DEBUG=false
    DEBUG_DIR_SUFFIX=
else
    IS_DEBUG=true
    DEBUG_DIR_SUFFIX=/debug
fi

if [[ "$TARGET_OS" == "mac" || "$TARGET_OS" == "ios" || "$TARGET_OS" == "android" ]]; then
  IS_CLANG=true
else
  IS_CLANG=false
fi

if [[ "$TARGET_OS" == "ios" && "$GN_ARCH" == "arm"* ]]; then
  ENABLE_BIT_CODE=false #true
else
  ENABLE_BIT_CODE=false
fi

cd $WORK_DIR
if [ ! -d pdfium/.git/index ]; then
    gclient config --unmanaged https://pdfium.googlesource.com/pdfium.git

    if [ "$TARGET_OS" == "android" ]; then
      echo "target_os = [ 'android' ]" >> $DEPOT_DIR/../.gclient
    fi

    gclient sync -vvv
fi

ROOTDIR=$(pwd)
if [[ "$TARGET_OS" == "android" && ! -e $ROOTDIR/.android.deps ]]; then
  $ROOTDIR/pdfium/build/install-build-deps-android.sh
  touch $ROOTDIR/.android.deps
fi

PDFIUM_SRCDIR=$ROOTDIR/pdfium
BUILDDIR=$PDFIUM_SRCDIR/out/$SOBAR_TARGET_STR$DEBUG_DIR_SUFFIX
mkdir -p $BUILDDIR

if [ "$LAST_KNOWN_GOOD_COMMIT" != "" ]; then
  pushd pdfium
  git reset --hard
  git checkout $LAST_KNOWN_GOOD_COMMIT
  popd
fi

if [ "$TARGET_OS" == "android" && ! -e $ROOTDIR/.android.patched ]; then
  file=$PDFIUM_SRCDIR/core/fxge/android/cfpf_skiafont.cpp
  echo -e "#pragma clang diagnostic ignored \"-Wshorten-64-to-32\"\n$(cat $file)" > $file
  file=$PDFIUM_SRCDIR/core/fxge/android/cfpf_skiafontmgr.cpp
  echo -e "#pragma clang diagnostic ignored \"-Wshorten-64-to-32\"\n$(cat $file)" > $file
  touch $ROOTDIR/.android.patched
fi

if [[ "$TARGET_OS" == "ios" ]]; then
  sed -i.bak -E "s/\"\/\/testing\/iossim\"//" $PDFIUM_SRCDIR/build/config/ios/rules.gni
  sed -i.bak -E "s/# TEST SETUP/ios_automatically_manage_certs = true/" $PDFIUM_SRCDIR/testing/test.gni
  sed -i.bak -E "s/(assert\(!is_ios,)/#\1/g" $PDFIUM_SRCDIR/third_party/libjpeg_turbo/BUILD.gn
  sed -i.bak -E "s/Carbon\/Carbon/CoreGraphics\/CoreGraphics/" $PDFIUM_SRCDIR/core/fpdfapi/font/cpdf_type1font.cpp
  sed -i.bak -E "s/Carbon\/Carbon/CoreGraphics\/CoreGraphics/" $PDFIUM_SRCDIR/core/fxge/apple/fx_quartz_device.h
  sed -i.bak -E "s/is_mac/is_ios/" $PDFIUM_SRCDIR/core/fxge/BUILD.gn
fi

cat <<EOF > $BUILDDIR/args.gn
is_clang = $IS_CLANG
use_custom_libcxx=false
target_os = "$TARGET_OS"
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

if [[ "$TARGET_OS" == "ios" ]]; then
cat <<EOF >> $BUILDDIR/args.gn
ios_enable_code_signing = false
#use_xcode_clang = true
enable_ios_bitcode= $ENABLE_BIT_CODE
EOF
fi

pushd $BUILDDIR
gn gen .
popd

ninja -C $BUILDDIR pdfium
