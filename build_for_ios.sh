#!/bin/bash
# Script to build Square Golf for iOS

echo "Building Square Golf for iOS..."

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: Xcode is not installed or not in your PATH."
    echo "Please install Xcode from the App Store and make sure the command line tools are installed."
    exit 1
fi

# Create a temporary directory for building
BUILD_DIR="./build/ios"
mkdir -p "$BUILD_DIR"

# Create the .love file
echo "Creating .love file..."
zip -9 -r "$BUILD_DIR/squaregolf.love" . -x "*.git*" "*.DS_Store" "build/*" "*.apk" "*.ipa"

# Check if LOVE for iOS is installed
LOVE_IOS_DIR="./love-ios"
if [ ! -d "$LOVE_IOS_DIR" ]; then
    echo "LOVE for iOS not found. Downloading..."
    git clone https://github.com/love2d/love-ios.git "$LOVE_IOS_DIR"
    
    # Check if the clone was successful
    if [ $? -ne 0 ]; then
        echo "Failed to download LOVE for iOS. Please check your internet connection."
        exit 1
    fi
fi

# Copy the .love file to the LOVE for iOS resources directory
echo "Copying .love file to LOVE for iOS..."
mkdir -p "$LOVE_IOS_DIR/platform/xcode/love-ios/Resources"
cp "$BUILD_DIR/squaregolf.love" "$LOVE_IOS_DIR/platform/xcode/love-ios/Resources/game.love"

# Update the app name in Info.plist
echo "Updating app name..."
INFO_PLIST="$LOVE_IOS_DIR/platform/xcode/love-ios/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Square Golf" "$INFO_PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleName Square Golf" "$INFO_PLIST"

# Open the Xcode project
echo "Opening Xcode project..."
open "$LOVE_IOS_DIR/platform/xcode/love.xcodeproj"

echo "Build preparation completed!"
echo ""
echo "To complete the build process:"
echo "1. In Xcode, select your iOS device or simulator as the build target"
echo "2. Update the Bundle Identifier to your own (e.g., com.yourdomain.squaregolf)"
echo "3. Set up your Apple Developer account in Xcode if you haven't already"
echo "4. Click the Build and Run button (or press Cmd+R)"
echo ""
echo "Note: To distribute the app to the App Store, you'll need to:"
echo "1. Create an App Store Connect entry for your app"
echo "2. Configure the appropriate provisioning profiles in Xcode"
echo "3. Archive the app (Product > Archive) and upload it through the Organizer"
echo ""
echo "The .love file is available at: $BUILD_DIR/squaregolf.love"
