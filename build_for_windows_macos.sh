#!/bin/bash
# Square Golf - macOS Script to Build Windows Version
# This script builds a Windows version of your LÖVE game while running on macOS

# Set text colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}Square Golf - macOS Script to Build Windows Version${NC}"
echo -e "${CYAN}=================================================${NC}"
echo ""

# Set variables
GAME_NAME="square-golf"
LOVE_VERSION="11.3"
LOVE_WIN_ZIP="love-$LOVE_VERSION-win64.zip"
LOVE_WIN_URL="https://github.com/love2d/love/releases/download/$LOVE_VERSION/$LOVE_WIN_ZIP"
BUILD_DIR="build/windows"
DIST_DIR="$BUILD_DIR/$GAME_NAME-win64"

# Create build directory if it doesn't exist
mkdir -p "$BUILD_DIR"
echo "Using build directory: $BUILD_DIR"

# Step 1: Create .love file
echo -e "\n${GREEN}Step 1: Creating .love file...${NC}"
echo -e "${GREEN}------------------------------${NC}"

# Create a .love file (which is just a zip file with a different extension)
echo "Creating .love file..."
zip -9 -r "$BUILD_DIR/$GAME_NAME.love" . -x "*.git*" "*.DS_Store" "build/*" "*.sh" "*.md"

if [ ! -f "$BUILD_DIR/$GAME_NAME.love" ]; then
    echo -e "${RED}Failed to create .love file!${NC}"
    exit 1
fi

echo -e "${GREEN}.love file created successfully: $BUILD_DIR/$GAME_NAME.love${NC}"

# Step 2: Download Windows LÖVE binaries
echo -e "\n${GREEN}Step 2: Downloading Windows LÖVE binaries...${NC}"
echo -e "${GREEN}------------------------------------------${NC}"

if [ -f "$BUILD_DIR/love.exe" ]; then
    echo "Windows LÖVE binaries already exist in build directory."
else
    echo "Downloading Windows LÖVE binaries..."
    
    # Download the Windows ZIP
    curl -L "$LOVE_WIN_URL" -o "$BUILD_DIR/$LOVE_WIN_ZIP"
    
    if [ ! -f "$BUILD_DIR/$LOVE_WIN_ZIP" ]; then
        echo -e "${RED}Failed to download Windows LÖVE binaries!${NC}"
        echo "Please download manually from https://love2d.org/ and extract to $BUILD_DIR"
        exit 1
    fi
    
    # Extract the ZIP
    echo "Extracting Windows LÖVE binaries..."
    unzip -q "$BUILD_DIR/$LOVE_WIN_ZIP" -d "$BUILD_DIR"
    
    # Move files from the nested directory to the build directory
    find "$BUILD_DIR" -name "love-*-win*" -type d | while read dir; do
        cp -R "$dir"/* "$BUILD_DIR/"
        rm -rf "$dir"
    done
    
    # Clean up the ZIP file
    rm "$BUILD_DIR/$LOVE_WIN_ZIP"
fi

# Step 3: Create Windows executable
echo -e "\n${GREEN}Step 3: Creating Windows executable...${NC}"
echo -e "${GREEN}-----------------------------------${NC}"

if [ -f "$BUILD_DIR/love.exe" ]; then
    echo "Creating Windows executable..."
    
    # On macOS, we need to use 'cat' to combine binary files
    cat "$BUILD_DIR/love.exe" "$BUILD_DIR/$GAME_NAME.love" > "$BUILD_DIR/$GAME_NAME.exe"
    
    if [ ! -f "$BUILD_DIR/$GAME_NAME.exe" ]; then
        echo -e "${RED}Failed to create Windows executable!${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Windows executable created successfully: $BUILD_DIR/$GAME_NAME.exe${NC}"
else
    echo -e "${RED}love.exe not found in build directory!${NC}"
    exit 1
fi

# Step 4: Finalize package
echo -e "\n${GREEN}Step 4: Finalizing Windows package...${NC}"
echo -e "${GREEN}----------------------------------${NC}"

# Create distribution directory
mkdir -p "$DIST_DIR"

# Copy the executable and required DLLs
cp "$BUILD_DIR/$GAME_NAME.exe" "$DIST_DIR/"
cp "$BUILD_DIR"/*.dll "$DIST_DIR/"
if [ -f "$BUILD_DIR/license.txt" ]; then
    cp "$BUILD_DIR/license.txt" "$DIST_DIR/"
fi

# Create a ZIP of the distribution directory
echo "Creating distribution ZIP file..."
(cd "$BUILD_DIR" && zip -9 -r "$GAME_NAME-win64.zip" "$GAME_NAME-win64")

echo -e "\n${GREEN}Build completed successfully!${NC}"
echo -e "\nYour game has been packaged for Windows in:"
echo -e "${CYAN}$DIST_DIR${NC}"
echo -e "and as a ZIP file at:"
echo -e "${CYAN}$BUILD_DIR/$GAME_NAME-win64.zip${NC}"
echo -e "\nThis package contains everything needed to run the game on Windows."
echo -e "You can distribute the ZIP file to Windows users."
echo -e "\nThank you for using Square Golf macOS-to-Windows Build Script!"
