#!/bin/bash
set -e

BASEDIR=$(dirname "$0")
cd "$BASEDIR"/../.. || exit 1
echo "Navigated to $(pwd)"

if [ -z "$1" ]; then
    echo "Vendor type is required"
    exit 1
fi

VTYPE=$1
BUILD_TYPE=${2:-release}
echo "Vendor: $VTYPE, Build type: $BUILD_TYPE"

chmod +x buildSrc/scripts/vendor_freetype.sh
buildSrc/scripts/vendor_freetype.sh "$VTYPE"

mkdir -p /tmp/imgui/dst

case "$VTYPE" in
    windows|linux|macos|android-arm64)
        echo "Running Gradle to generate libs..."
        ./gradlew imgui-binding:generateLibs -Denvs=$VTYPE -Dfreetype=true -PbuildType=$BUILD_TYPE
        ;;
    *)
        echo "Unknown vendor type: $VTYPE"
        exit 1
        ;;
esac

# Copy resulting libraries to /tmp/imgui/dst
if [ "$VTYPE" == "windows" ]; then
    cp /tmp/imgui/libsNative/windows64/imgui-java64.dll /tmp/imgui/dst/
elif [ "$VTYPE" == "linux" ]; then
    cp /tmp/imgui/libsNative/linux64/libimgui-java64.so /tmp/imgui/dst/
elif [ "$VTYPE" == "android-arm64" ]; then
    SO_FILE=$(find /tmp/imgui/libsNative/android-arm64/ -name "*.so" | head -n 1)
    cp "$SO_FILE" /tmp/imgui/dst/libimgui-java64.so
elif [ "$VTYPE" == "macos" ]; then
    cp /tmp/imgui/libsNative/macosx64/libimgui-java64.dylib /tmp/imgui/dst/
fi

echo "Build completed successfully."
