# Square Golf - Mobile Version

This document provides information about the mobile version of Square Golf, including how to build and deploy the game for mobile devices, and the mobile-specific features that have been implemented.

## Mobile Features

The game has been adapted for mobile devices with the following features:

### Touch Controls

- **Slingshot Aiming**: Touch and drag to aim the ball, release to shoot
- **Double Tap**: Reset the ball to its starting position

### Mobile UI

- **Large Touch Buttons**: Larger, touch-friendly buttons for common actions
- **On-screen Controls**: Visible buttons for reset and other common actions
- **Adaptive Layout**: UI elements adjust to different screen sizes and orientations
- **Mobile-friendly Text**: Larger text for better readability on small screens

### Performance Optimizations

- **Reduced Particle Effects**: Fewer particles on mobile to maintain performance
- **Cluster-Based Updates**: Only active areas of the level are updated each frame
- **Adaptive Resolution**: Game scales to match the device's screen resolution

## Building for Mobile

### Prerequisites

- LÖVE for Android or iOS (https://love2d.org/wiki/Getting_Started)
- Android SDK (for Android builds)
- Xcode (for iOS builds)

### Building for Android

1. **Install Android SDK**:
   - Download Android Studio from [developer.android.com](https://developer.android.com/studio)
   - During installation, make sure to install the Android SDK
   - After installation, set the ANDROID_SDK_ROOT environment variable:
     ```bash
     # For macOS/Linux, add to ~/.bashrc or ~/.zshrc
     export ANDROID_SDK_ROOT=~/Android/Sdk  # Adjust path as needed
     
     # For Windows, set in System Properties > Environment Variables
     # Variable name: ANDROID_SDK_ROOT
     # Variable value: C:\Users\YourUsername\AppData\Local\Android\Sdk
     ```
   - Restart your terminal or command prompt after setting the variable

2. **Run the Build Script**:
   ```bash
   # Make the script executable (macOS/Linux)
   chmod +x build_for_android.sh
   
   # Run the script
   ./build_for_android.sh
   ```

3. **What the Script Does**:
   - Creates a .love file by zipping the game directory
   - Downloads LÖVE for Android if not already present
   - Configures the app name and icon
   - Builds an unsigned APK using Gradle
   - The APK will be generated in `build/android/squaregolf-unsigned.apk`

4. **Signing the APK** (required for installation):
   - Create a keystore (one-time setup):
     ```bash
     keytool -genkey -v -keystore squaregolf.keystore -alias squaregolf -keyalg RSA -keysize 2048 -validity 10000
     ```
   - Sign the APK:
     ```bash
     jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 -keystore squaregolf.keystore build/android/squaregolf-unsigned.apk squaregolf
     ```
   - Align the APK:
     ```bash
     $ANDROID_SDK_ROOT/build-tools/<version>/zipalign -v 4 build/android/squaregolf-unsigned.apk build/android/squaregolf.apk
     ```

### Building for iOS

1. **Install Prerequisites**:
   - Install Xcode from the Mac App Store
   - Install the iOS SDK through Xcode
   - Install LÖVE for iOS:
     ```bash
     # Clone the LÖVE for iOS repository
     git clone https://github.com/love2d/love-ios.git
     ```

2. **Run the Build Script**:
   ```bash
   # Make the script executable
   chmod +x build_for_ios.sh
   
   # Run the script
   ./build_for_ios.sh
   ```

3. **What the Script Does**:
   - Creates a .love file by zipping the game directory
   - Configures the project for iOS
   - Opens the Xcode project automatically

4. **In Xcode**:
   - Connect your iOS device
   - Select your device as the build target
   - Set up your Apple Developer account in Xcode
   - Click the Build and Run button (or press Cmd+R)
   - If building for the App Store, use the Archive option in the Product menu

5. **Troubleshooting**:
   - If you encounter code signing issues, make sure your Apple Developer account is properly set up in Xcode
   - For "App Installation Failed" errors, check that your device is trusted in your Apple account
   - Make sure your provisioning profile includes the device you're trying to install on

## Mobile Features Now Enabled by Default with Simplified Controls

The mobile features are now enabled by default on all platforms, including desktop, with simplified controls focused on the core shooting gameplay. This means:

- Touch input simulation with mouse is active
- Mobile UI with larger buttons is displayed
- Performance optimizations are applied
- Simplified controls focused on shooting only

If you prefer the traditional desktop experience, you can disable mobile features by pressing the 'D' key when starting the game.

## Mobile-Specific Configuration

The game automatically detects if it's running on a mobile device and adjusts the following settings:

- Enables touch input
- Scales UI elements for touch
- Adjusts performance settings for mobile hardware
- Enables mobile-specific UI elements

## Known Issues and Limitations

- The editor mode is not fully optimized for mobile devices and may be difficult to use on smaller screens
- Some advanced features may be limited on lower-end mobile devices
- Performance may vary depending on the device's capabilities

## Tips for Mobile Players

- Use landscape orientation for the best experience
- Touch and drag to aim and shoot the ball
- Double tap to reset the ball if you get stuck
- Use the on-screen buttons for common actions
