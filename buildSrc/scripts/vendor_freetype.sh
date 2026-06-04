#!/bin/bash
set -e

# Set base directory and navigate to project root
echo "Setting base directory and navigating to project root..."
BASEDIR=$(dirname "$0")
cd "$BASEDIR"/../.. || exit 1
echo "Navigated to $(pwd)"

# Check if vendor type argument is provided
if [ -z "$1" ]; then
    echo "Vendor type is required"
    exit 1
fi

VTYPE=$1
echo "Vendor type set to '$VTYPE'"

# Define library directory and version
LIBDIR=build/vendor/freetype
VERSION=2.13.3

# Clean and create library directory, then extract FreeType source
echo "Cleaning and creating library directory, then extracting FreeType source..."
rm -rf $LIBDIR
mkdir -p $LIBDIR
tar -xzf ./vendor/freetype-$VERSION.tar.gz -C $LIBDIR --strip-components=1
cd $LIBDIR || exit 1
echo "FreeType unzipped to $LIBDIR"

COMMON_FLAGS="--enable-static --disable-shared --without-zlib --without-bzip2 --without-png --without-harfbuzz --without-brotli"

build_freetype() {
    cflags=$1
    prefix=$2
    output_dir=$3

    echo "Cleaning previous builds..."
    make clean || true

    echo "Configuring FreeType with CFLAGS='$cflags' and PREFIX='$prefix'..."
    ./configure CFLAGS="$cflags" $COMMON_FLAGS $prefix
    echo "Building FreeType..."
    make

    echo "Copying library to $output_dir..."
    mkdir -p $(dirname "$output_dir")
    cp objs/.libs/libfreetype.a "$output_dir"
}

mkdir -p lib tmp

case "$VTYPE" in
    windows)
        build_freetype "" "--host=x86_64-w64-mingw32 --prefix=/usr/x86_64-w64-mingw32" "lib/libfreetype.a"
        ;;
    linux)
        build_freetype "-fPIC" "" "lib/libfreetype.a"
        ;;
    macos)
        MACOS_VERSION=10.15
        build_freetype "-arch x86_64 -mmacosx-version-min=$MACOS_VERSION" "" "tmp/libfreetype-x86_64.a"
        build_freetype "-arch arm64 -mmacosx-version-min=$MACOS_VERSION" "" "tmp/libfreetype-arm64.a"
        echo "Creating universal library using lipo..."
        lipo -create -output lib/libfreetype.a tmp/libfreetype-x86_64.a tmp/libfreetype-arm64.a
        ;;
    android-arm64)
        if [ -z "$ANDROID_NDK_HOME" ]; then
            echo "ANDROID_NDK_HOME not set!"
            exit 1
        fi
        TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"
        export CC="$TOOLCHAIN/bin/aarch64-linux-android24-clang"
        export CXX="$TOOLCHAIN/bin/aarch64-linux-android24-clang++"
        export AR="$TOOLCHAIN/bin/llvm-ar"
        export RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
        export STRIP="$TOOLCHAIN/bin/llvm-strip"
        build_freetype "-fPIC" "--host=aarch64-linux-android --prefix=$PWD/output" "lib/libfreetype.a"
        ;;
    *)
        echo "Unknown vendor type: $VTYPE"
        exit 1
        ;;
esac

echo "vendor_freetype.sh completed successfully."
