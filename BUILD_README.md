# Square Golf - Windows Build Scripts

This directory contains scripts to help you build and package Square Golf for Windows distribution. These scripts automate the process of creating a standalone Windows executable that users can run without installing LÖVE separately.

## Available Build Scripts

Three build scripts are provided for your convenience:

1. **build_for_windows.bat** - Windows Batch Script
2. **build_for_windows.ps1** - Windows PowerShell Script
3. **build_for_windows_macos.sh** - macOS Shell Script (for building Windows versions on macOS)

The scripts perform the same functions, so you can choose whichever one is appropriate for your operating system.

## What the Scripts Do

The build scripts automate the following process:

1. Create a `.love` file from your game directory
2. Download LÖVE binaries if they're not already present
3. Combine the `.love` file with `love.exe` to create a standalone executable
4. Package everything into a distribution folder with all required DLLs

## How to Use the Scripts

### Using the Batch Script (build_for_windows.bat)

1. Open Command Prompt
2. Navigate to your game directory
3. Run the batch script:
   ```
   build_for_windows.bat
   ```

### Using the PowerShell Script (build_for_windows.ps1)

1. Open PowerShell
2. Navigate to your game directory
3. Run the PowerShell script:
   ```
   .\build_for_windows.ps1
   ```
   
   If you encounter a security error, you may need to adjust the PowerShell execution policy:
   ```
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   .\build_for_windows.ps1
   ```

### Using the macOS Shell Script (build_for_windows_macos.sh)

1. Open Terminal
2. Navigate to your game directory
3. Make the script executable (first time only):
   ```
   chmod +x build_for_windows_macos.sh
   ```
4. Run the shell script:
   ```
   ./build_for_windows_macos.sh
   ```

## Build Output

After running either script, you'll find your packaged game in:

```
build\windows\square-golf-win64\
```

This folder contains:
- `square-golf.exe` - The standalone executable
- Various `.dll` files required by LÖVE
- `license.txt` - The LÖVE license file

You can distribute this entire folder to users, or compress it into a ZIP file for easier distribution.

## Requirements

### For Windows Scripts
- **Windows OS**: The batch and PowerShell scripts are designed to run on Windows
- **PowerShell**: Required for the PowerShell script, included in all modern Windows versions
- **Internet Connection**: Required to download LÖVE binaries (unless already present)
- **7-Zip** (Optional): If installed, it will be used for better compression

### For macOS Script
- **macOS**: The shell script is designed to run on macOS
- **Bash**: Required for the shell script (included in macOS)
- **curl**: Required for downloading (included in macOS)
- **unzip**: Required for extracting ZIP files (included in macOS)
- **Internet Connection**: Required to download LÖVE binaries (unless already present)

## Troubleshooting

If you encounter any issues:

1. **Script fails to create .love file**:
   - Ensure you're running the script from the game's root directory
   - Check if you have write permissions in the build directory

2. **Script fails to download LÖVE binaries**:
   - Check your internet connection
   - Download the LÖVE binaries manually from https://love2d.org/
   - Extract them to `build\windows\`

3. **PowerShell script security error**:
   - Run PowerShell as Administrator
   - Use the execution policy command mentioned above

4. **Game crashes on startup**:
   - Ensure all required DLL files are included in the distribution
   - Check if your game is compatible with the LÖVE version being used

## For More Information

For more detailed information about building LÖVE games for Windows, see the `WINDOWS_BUILD_GUIDE.md` file.
