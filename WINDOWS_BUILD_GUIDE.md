# Building Square Golf for Windows

This guide will walk you through the process of packaging the Square Golf game for Windows distribution, whether you're working on Windows or macOS.

## Method 1: Creating a Simple .love File

The easiest way to distribute your game is to create a .love file, which users with LÖVE installed can run directly.

1. **Create a .love file**:
   - Select all files and folders in your game directory (excluding any build files or unnecessary development files)
   - Compress them into a ZIP file
   - Rename the .zip extension to .love (e.g., `square-golf.love`)

   ```
   # On Windows, you can use PowerShell:
   Compress-Archive -Path * -DestinationPath square-golf.zip
   Rename-Item -Path square-golf.zip -NewName square-golf.love
   
   # On macOS/Linux, you can use the terminal:
   zip -9 -r square-golf.love .
   ```

2. **Running the .love file**:
   - Users will need to have LÖVE installed on their Windows machine
   - They can double-click the .love file to run it (if LÖVE is properly installed)
   - Alternatively, they can drag the .love file onto the love.exe executable

## Method 2: Creating a Standalone Windows Executable (Recommended)

This method creates a standalone .exe that users can run without installing LÖVE separately.

1. **Download the LÖVE for Windows ZIP**:
   - Go to https://love2d.org/
   - Download the Windows 64-bit ZIP (e.g., `love-11.3-win64.zip`)
   - Extract the ZIP to a folder

2. **Create a .love file** as described in Method 1

3. **Combine the .love file with love.exe**:
   - Copy all files from the LÖVE Windows ZIP to a new folder (e.g., `square-golf-win`)
   - Use the command prompt to combine love.exe with your .love file:
   
   ```
   copy /b love.exe+square-golf.love square-golf.exe
   ```

4. **Package the game**:
   - Your new folder should contain:
     - `square-golf.exe` (your newly created executable)
     - All DLL files from the LÖVE distribution
     - `license.txt` and other LÖVE documentation files (optional)
   - This folder now contains everything needed to run the game on Windows

5. **Create a ZIP archive** of this folder for distribution

## Method 3: Using Love-Release Tool (Advanced)

For more advanced packaging with custom icons and automated builds:

1. **Install Node.js** if you don't have it already

2. **Install love-release globally**:
   ```
   npm install -g love-release
   ```

3. **Run love-release** from your game directory:
   ```
   love-release -W 64 -n "Square Golf"
   ```

   This will create Windows 64-bit builds in a `releases` folder.

4. **Additional options**:
   - Add a custom icon: `love-release -W 64 -n "Square Golf" -i path/to/icon.ico`
   - Include specific files: `love-release -W 64 -n "Square Golf" -p "*.lua;*.ttf;*.mp3;src/**;fonts/**;sounds/**"`

## Method 4: Building for Windows from macOS (Cross-Platform)

You can build a Windows version of your game even if you're developing on macOS:

1. **Create a .love file** on macOS:
   ```
   zip -9 -r square-golf.love . -x "*.git*" "*.DS_Store" "build/*"
   ```

2. **Download the Windows version of LÖVE**:
   - Go to https://love2d.org/
   - Download the Windows 64-bit ZIP (e.g., `love-11.3-win64.zip`)
   - Extract the ZIP to a folder

3. **Combine the .love file with love.exe**:
   - On macOS, use the `cat` command to combine binary files:
   ```
   cat love.exe square-golf.love > square-golf.exe
   ```

4. **Package the game**:
   - Create a distribution folder containing:
     - Your newly created `square-golf.exe`
     - All DLL files from the LÖVE Windows distribution
   - Zip this folder for distribution to Windows users

5. **Use the provided script**:
   - For convenience, use the included `build_for_windows_macos.sh` script
   - This automates all the steps above
   - Run it with: `./build_for_windows_macos.sh`

## Method 5: Using LÖVE Game Packager GUI Tools

There are several GUI tools that can simplify the packaging process:

1. **LÖVE Packager** (https://github.com/ellraiser/love-packager)
   - A simple GUI tool for packaging LÖVE games
   - Supports custom icons and multiple platforms

2. **LÖVE Maker** (https://github.com/poucotm/LOVE-Maker)
   - Visual Studio Code extension for packaging LÖVE games
   - Integrates with your development environment

## Distribution Considerations

1. **File Size Optimization**:
   - Consider compressing sound files if they're large
   - Remove any unused assets or debug features

2. **Version Information**:
   - Consider adding version information to your game title or a separate version file
   - This helps users know which version they're running

3. **Windows Compatibility**:
   - Test your game on different Windows versions if possible
   - Ensure file paths use proper separators (LÖVE handles this, but custom file operations might need attention)

4. **Antivirus Considerations**:
   - Some antivirus software may flag custom-packaged executables
   - Consider signing your executable or providing instructions for users who encounter warnings

## Troubleshooting

- If the game crashes on startup, ensure all required DLL files from the LÖVE distribution are included
- If you encounter "missing DLL" errors, make sure you're using the correct version of LÖVE that matches your game's requirements (check conf.lua)
- For performance issues, consider adjusting the game's settings for lower-end machines
