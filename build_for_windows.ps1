# Square Golf - Windows Build PowerShell Script

Write-Host "Square Golf - Windows Build Script" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Set variables
$GAME_NAME = "square-golf"
$LOVE_VERSION = "11.3"
$LOVE_ZIP = "love-$LOVE_VERSION-win64.zip"
$LOVE_URL = "https://github.com/love2d/love/releases/download/$LOVE_VERSION/$LOVE_ZIP"
$BUILD_DIR = "build\windows"
$DIST_DIR = "$BUILD_DIR\$GAME_NAME-win64"

# Create build directory if it doesn't exist
if (-not (Test-Path $BUILD_DIR)) {
    New-Item -ItemType Directory -Path $BUILD_DIR | Out-Null
    Write-Host "Created build directory: $BUILD_DIR"
}

# Step 1: Create .love file
Write-Host "Step 1: Creating .love file..." -ForegroundColor Green
Write-Host "------------------------------" -ForegroundColor Green

# Check if 7-Zip is installed
$use7Zip = $null -ne (Get-Command "7z.exe" -ErrorAction SilentlyContinue)

if ($use7Zip) {
    Write-Host "Using 7-Zip for compression..."
    & 7z a -tzip "$BUILD_DIR\$GAME_NAME.love" *.lua src fonts sounds -xr!build -xr!.git -xr!*.bat -xr!*.ps1
} else {
    Write-Host "Using PowerShell for compression..."
    
    # Create a temporary directory for the .love file contents
    $tempDir = "$BUILD_DIR\temp_love"
    if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force }
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    
    # Copy required files to the temp directory
    Copy-Item -Path "*.lua" -Destination $tempDir -Recurse
    Copy-Item -Path "src" -Destination $tempDir -Recurse
    Copy-Item -Path "fonts" -Destination $tempDir -Recurse
    Copy-Item -Path "sounds" -Destination $tempDir -Recurse
    
    # Create the .love file (which is just a zip file with a different extension)
    Compress-Archive -Path "$tempDir\*" -DestinationPath "$BUILD_DIR\$GAME_NAME.zip" -Force
    Rename-Item -Path "$BUILD_DIR\$GAME_NAME.zip" -NewName "$GAME_NAME.love" -Force
    
    # Clean up the temp directory
    Remove-Item -Path $tempDir -Recurse -Force
}

if (-not (Test-Path "$BUILD_DIR\$GAME_NAME.love")) {
    Write-Host "Failed to create .love file!" -ForegroundColor Red
    exit 1
}

Write-Host ".love file created successfully: $BUILD_DIR\$GAME_NAME.love" -ForegroundColor Green
Write-Host ""

# Step 2: Check for LÖVE binaries
Write-Host "Step 2: Checking for LÖVE binaries..." -ForegroundColor Green
Write-Host "------------------------------------" -ForegroundColor Green

if (Test-Path "$BUILD_DIR\love.exe") {
    Write-Host "LÖVE binaries found in build directory."
} else {
    Write-Host "LÖVE binaries not found. Downloading..."
    
    try {
        # Download LÖVE binaries
        Write-Host "Downloading LÖVE $LOVE_VERSION..."
        Invoke-WebRequest -Uri $LOVE_URL -OutFile "$BUILD_DIR\$LOVE_ZIP"
        
        if (Test-Path "$BUILD_DIR\$LOVE_ZIP") {
            Write-Host "Extracting LÖVE binaries..."
            Expand-Archive -Path "$BUILD_DIR\$LOVE_ZIP" -DestinationPath "$BUILD_DIR" -Force
            
            # Move files from the nested directory to the build directory
            Get-ChildItem -Path "$BUILD_DIR" -Directory -Filter "love*win*" | ForEach-Object {
                Copy-Item -Path "$($_.FullName)\*" -Destination "$BUILD_DIR\" -Recurse -Force
                Remove-Item -Path $_.FullName -Recurse -Force
            }
            
            # Clean up the zip file
            Remove-Item -Path "$BUILD_DIR\$LOVE_ZIP" -Force
        } else {
            Write-Host "Failed to download LÖVE binaries." -ForegroundColor Red
            Write-Host "Please download manually from https://love2d.org/ and extract to $BUILD_DIR"
            exit 1
        }
    } catch {
        Write-Host "Error downloading LÖVE binaries: $_" -ForegroundColor Red
        Write-Host "Please download LÖVE $LOVE_VERSION manually from https://love2d.org/"
        Write-Host "Extract the files to $BUILD_DIR"
        exit 1
    }
}

Write-Host ""

# Step 3: Create standalone executable
Write-Host "Step 3: Creating standalone executable..." -ForegroundColor Green
Write-Host "---------------------------------------" -ForegroundColor Green

if (Test-Path "$BUILD_DIR\love.exe") {
    Write-Host "Creating standalone executable..."
    
    # Combine love.exe with the .love file
    $bytes = [System.IO.File]::ReadAllBytes("$BUILD_DIR\love.exe")
    $loveBytes = [System.IO.File]::ReadAllBytes("$BUILD_DIR\$GAME_NAME.love")
    $combinedBytes = New-Object byte[] ($bytes.Length + $loveBytes.Length)
    [System.Buffer]::BlockCopy($bytes, 0, $combinedBytes, 0, $bytes.Length)
    [System.Buffer]::BlockCopy($loveBytes, 0, $combinedBytes, $bytes.Length, $loveBytes.Length)
    [System.IO.File]::WriteAllBytes("$BUILD_DIR\$GAME_NAME.exe", $combinedBytes)
    
    if (Test-Path "$BUILD_DIR\$GAME_NAME.exe") {
        Write-Host "Standalone executable created successfully: $BUILD_DIR\$GAME_NAME.exe" -ForegroundColor Green
    } else {
        Write-Host "Failed to create standalone executable!" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "love.exe not found in build directory!" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 4: Finalize package
Write-Host "Step 4: Finalizing package..." -ForegroundColor Green
Write-Host "---------------------------" -ForegroundColor Green

# Create distribution directory
if (-not (Test-Path $DIST_DIR)) {
    New-Item -ItemType Directory -Path $DIST_DIR | Out-Null
}

# Copy the executable and required DLLs
Copy-Item -Path "$BUILD_DIR\$GAME_NAME.exe" -Destination $DIST_DIR
Copy-Item -Path "$BUILD_DIR\*.dll" -Destination $DIST_DIR
if (Test-Path "$BUILD_DIR\license.txt") {
    Copy-Item -Path "$BUILD_DIR\license.txt" -Destination $DIST_DIR
}

Write-Host ""
Write-Host "Build completed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Your game has been packaged for Windows in:" -ForegroundColor Cyan
Write-Host "$DIST_DIR" -ForegroundColor Cyan
Write-Host ""
Write-Host "This folder contains everything needed to run the game on Windows."
Write-Host "You can zip this folder and distribute it to users."
Write-Host ""
Write-Host "Thank you for using Square Golf Windows Build Script!" -ForegroundColor Cyan

# Pause at the end
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
