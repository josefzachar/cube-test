#!/bin/bash
# Script to build Square Golf for Android

echo "Building Square Golf for Android..."

# Check if the ANDROID_SDK_ROOT environment variable is set
if [ -z "$ANDROID_SDK_ROOT" ]; then
    echo "Error: ANDROID_SDK_ROOT environment variable is not set."
    echo "Please set it to your Android SDK location, for example:"
    echo "export ANDROID_SDK_ROOT=~/Android/Sdk"
    exit 1
fi

# Create a temporary directory for building
BUILD_DIR="./build/android"
mkdir -p "$BUILD_DIR"

# Create the .love file
echo "Creating .love file..."
zip -9 -r "$BUILD_DIR/squaregolf.love" . -x "*.git*" "*.DS_Store" "build/*" "*.apk" "*.ipa"

# Check if LOVE for Android is installed
LOVE_ANDROID_DIR="./love-android"
if [ ! -d "$LOVE_ANDROID_DIR" ]; then
    echo "LOVE for Android not found. Downloading..."
    git clone https://github.com/love2d/love-android.git "$LOVE_ANDROID_DIR"
    
    # Check if the clone was successful
    if [ $? -ne 0 ]; then
        echo "Failed to download LOVE for Android. Please check your internet connection."
        exit 1
    fi
fi

# Copy the .love file to the LOVE for Android assets directory
echo "Copying .love file to LOVE for Android..."
mkdir -p "$LOVE_ANDROID_DIR/app/src/main/assets"
cp "$BUILD_DIR/squaregolf.love" "$LOVE_ANDROID_DIR/app/src/main/assets/game.love"

# Update the app name in strings.xml
echo "Updating app name..."
STRINGS_XML="$LOVE_ANDROID_DIR/app/src/main/res/values/strings.xml"
sed -i '' 's/<string name="app_name">LÖVE for Android<\/string>/<string name="app_name">Square Golf<\/string>/g' "$STRINGS_XML" 2>/dev/null || \
sed -i 's/<string name="app_name">LÖVE for Android<\/string>/<string name="app_name">Square Golf<\/string>/g' "$STRINGS_XML"

# Build the APK
echo "Building APK..."
cd "$LOVE_ANDROID_DIR"
./gradlew assembleRelease

# Check if the build was successful
if [ $? -ne 0 ]; then
    echo "Failed to build APK. Please check the error messages above."
    exit 1
fi

# Copy the APK to the build directory
echo "Copying APK to build directory..."
cp "$LOVE_ANDROID_DIR/app/build/outputs/apk/release/app-release-unsigned.apk" "$BUILD_DIR/squaregolf-unsigned.apk"

echo "Build completed successfully!"
echo "Unsigned APK is available at: $BUILD_DIR/squaregolf-unsigned.apk"
echo ""
echo "To sign the APK, you need to:"
echo "1. Create a keystore (if you don't have one):"
echo "   keytool -genkey -v -keystore squaregolf.keystore -alias squaregolf -keyalg RSA -keysize 2048 -validity 10000"
echo ""
echo "2. Sign the APK:"
echo "   jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 -keystore squaregolf.keystore $BUILD_DIR/squaregolf-unsigned.apk squaregolf"
echo ""
echo "3. Align the APK:"
echo "   \$ANDROID_SDK_ROOT/build-tools/<version>/zipalign -v 4 $BUILD_DIR/squaregolf-unsigned.apk $BUILD_DIR/squaregolf.apk"
