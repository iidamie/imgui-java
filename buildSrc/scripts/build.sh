#!/bin/bash

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

# Make the vendor FreeType script executable and run it
echo "Making vendor FreeType script executable and running it..."
chmod +x buildSrc/scripts/vendor_freetype.sh
buildSrc/scripts/vendor_freetype.sh "$VTYPE"
if [ $? -ne 0 ]; then
    echo "Vendor FreeType script failed"
    exit 1
fi
echo "Vendor FreeType script completed successfully"

# Create the destination directory for imgui libraries
echo "Creating destination directory for imgui libraries..."
mkdir -p /tmp/imgui/dst
echo "Directory /tmp/imgui/dst created successfully"

# Set Android NDK paths if building for Android
if [ "$VTYPE" = "android-arm64" ]; then
    if [ -z "$ANDROID_NDK_HOME" ]; then
        echo "ANDROID_NDK_HOME is not set! Please set it to your Android NDK path."
        exit 1
    fi
    echo "Android NDK Home: $ANDROID_NDK_HOME"
    
    # Set up toolchain variables for Android
    export ANDROID_ABI=arm64-v8a
    export ANDROID_PLATFORM=android-24
    export ANDROID_STL=c++_shared
    
    # Set the toolchain paths
    TOOLCHAIN_PATH="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64"
    export CC="$TOOLCHAIN_PATH/bin/aarch64-linux-android24-clang"
    export CXX="$TOOLCHAIN_PATH/bin/aarch64-linux-android24-clang++"
    export AR="$TOOLCHAIN_PATH/bin/llvm-ar"
    export RANLIB="$TOOLCHAIN_PATH/bin/llvm-ranlib"
    export STRIP="$TOOLCHAIN_PATH/bin/llvm-strip"
    
    echo "CC set to: $CC"
    echo "CXX set to: $CXX"
fi

# Function to check if a file exists
check_file_exists() {
    if [ ! -f "$1" ]; then
        echo "File $1 not found!"
        exit 1
    fi
}

# Determine build process based on vendor type
case "$VTYPE" in
    windows)
        echo "Running Gradle task for Windows..."
        ./gradlew imgui-binding:generateLibs -Denvs=windows -Dfreetype=true
        if [ $? -ne 0 ]; then
            echo "Gradle task for Windows failed"
            exit 1
        fi

        echo "Checking if the generated DLL exists..."
        check_file_exists /tmp/imgui/libsNative/windows64/imgui-java64.dll

        echo "Copying the generated DLL to the destination directory..."
        cp /tmp/imgui/libsNative/windows64/imgui-java64.dll /tmp/imgui/dst/imgui-java64.dll
        if [ $? -ne 0 ]; then
            echo "Failed to copy DLL to /tmp/imgui/dst/imgui-java64.dll"
            exit 1
        fi
        echo "DLL copied to /tmp/imgui/dst/imgui-java64.dll successfully"
        ;;
    linux)
        echo "Running Gradle task for Linux..."
        ./gradlew imgui-binding:generateLibs -Denvs=linux -Dfreetype=true
        if [ $? -ne 0 ]; then
            echo "Gradle task for Linux failed"
            exit 1
        fi

        echo "Checking if the generated SO file exists..."
        check_file_exists /tmp/imgui/libsNative/linux64/libimgui-java64.so

        echo "Copying the generated SO file to the destination directory..."
        cp /tmp/imgui/libsNative/linux64/libimgui-java64.so /tmp/imgui/dst/libimgui-java64.so
        if [ $? -ne 0 ]; then
            echo "Failed to copy SO file to /tmp/imgui/dst/libimgui-java64.so"
            exit 1
        fi
        echo "SO file copied to /tmp/imgui/dst/libimgui-java64.so successfully"
        ;;
    android-arm64)
        echo "Running Gradle task for Android ARM64..."
        # Pass Android-specific properties to Gradle
        ./gradlew imgui-binding:generateLibs \
            -Denvs=android-arm64 \
            -Dfreetype=true \
            -Dandroid.ndk=$ANDROID_NDK_HOME \
            -Dandroid.abi=arm64-v8a \
            -Dandroid.platform=24
        if [ $? -ne 0 ]; then
            echo "Gradle task for Android ARM64 failed"
            exit 1
        fi

        echo "Checking if the generated SO file exists..."
        # Check both possible locations
        if [ -f /tmp/imgui/libsNative/android-arm64/libimgui-java64.so ]; then
            SO_FILE="/tmp/imgui/libsNative/android-arm64/libimgui-java64.so"
        elif [ -f /tmp/imgui/libsNative/android64/libimgui-java64.so ]; then
            SO_FILE="/tmp/imgui/libsNative/android64/libimgui-java64.so"
        else
            echo "Generated SO file not found!"
            echo "Searching for .so files in /tmp/imgui/libsNative/..."
            find /tmp/imgui/libsNative/ -name "*.so" -type f
            exit 1
        fi
        
        echo "Found SO file at: $SO_FILE"
        
        # Verify the architecture
        echo "Verifying file architecture..."
        file "$SO_FILE"
        
        # Check if it's actually ARM64
        if file "$SO_FILE" | grep -q "ARM aarch64"; then
            echo "✓ File is ARM64 architecture"
        else
            echo "✗ Warning: File may not be ARM64 architecture!"
            echo "Expected ARM aarch64, got:"
            file "$SO_FILE"
        fi
        
        # Strip debug symbols to reduce size
        echo "Stripping debug symbols..."
        if [ -n "$STRIP" ]; then
            "$STRIP" --strip-unneeded "$SO_FILE"
        else
            aarch64-linux-android-strip --strip-unneeded "$SO_FILE" 2>/dev/null || true
        fi
        
        echo "Copying the generated SO file to the destination directory..."
        cp "$SO_FILE" /tmp/imgui/dst/libimgui-java64.so
        if [ $? -ne 0 ]; then
            echo "Failed to copy SO file to /tmp/imgui/dst/libimgui-java64.so"
            exit 1
        fi
        echo "SO file copied to /tmp/imgui/dst/libimgui-java64.so successfully"
        
        # Also copy any additional Android-specific libraries if they exist
        if [ -f /tmp/imgui/libsNative/android-arm64/libfreetype.so ]; then
            echo "Copying FreeType library..."
            cp /tmp/imgui/libsNative/android-arm64/libfreetype.so /tmp/imgui/dst/
        fi
        ;;
    macos)
        echo "Running Gradle task for macOS and macOS ARM..."
        ./gradlew imgui-binding:generateLibs -Denvs=macos,macosarm64 -Dfreetype=true
        if [ $? -ne 0 ]; then
            echo "Gradle task for macOS failed"
            exit 1
        fi

        echo "Checking if the generated DYLIB files exist..."
        check_file_exists /tmp/imgui/libsNative/macosx64/libimgui-java64.dylib
        check_file_exists /tmp/imgui/libsNative/macosxarm64/libimgui-java64.dylib

        echo "Creating a universal library using lipo..."
        lipo -create -output /tmp/imgui/dst/libimgui-java64.dylib /tmp/imgui/libsNative/macosx64/libimgui-java64.dylib /tmp/imgui/libsNative/macosxarm64/libimgui-java64.dylib
        if [ $? -ne 0 ]; then
            echo "Failed to create universal library with lipo"
            exit 1
        fi
        echo "Universal library created at /tmp/imgui/dst/libimgui-java64.dylib successfully"
        ;;
    *)
        echo "Unknown vendor type: $VTYPE"
        echo "Supported types: windows, linux, macos, android-arm64"
        exit 1
        ;;
esac

# Final verification for Android build
if [ "$VTYPE" = "android-arm64" ]; then
    echo ""
    echo "=========================================="
    echo "Final verification of Android ARM64 build:"
    file /tmp/imgui/dst/libimgui-java64.so
    echo "=========================================="
fi

echo "Script completed successfully."
