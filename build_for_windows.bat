@echo off
setlocal enabledelayedexpansion

echo Square Golf - Windows Build Script
echo =================================
echo.

:: Set variables
set GAME_NAME=square-golf
set LOVE_VERSION=11.3
set LOVE_ZIP=love-%LOVE_VERSION%-win64.zip
set LOVE_URL=https://github.com/love2d/love/releases/download/%LOVE_VERSION%/%LOVE_ZIP%
set BUILD_DIR=build\windows

:: Create build directory
if not exist %BUILD_DIR% mkdir %BUILD_DIR%

echo Step 1: Creating .love file...
echo ------------------------------

:: Check if 7-Zip is installed (for better compression)
where 7z >nul 2>&1
if %ERRORLEVEL% == 0 (
    echo Using 7-Zip for compression...
    7z a -tzip "%BUILD_DIR%\%GAME_NAME%.love" *.lua src\* fonts\* sounds\* -xr!build -xr!.git -xr!*.bat
) else (
    echo Using PowerShell for compression...
    powershell -Command "Compress-Archive -Path *.lua, src, fonts, sounds -DestinationPath '%BUILD_DIR%\%GAME_NAME%.zip' -Force"
    rename "%BUILD_DIR%\%GAME_NAME%.zip" "%GAME_NAME%.love"
)

if not exist "%BUILD_DIR%\%GAME_NAME%.love" (
    echo Failed to create .love file!
    goto :error
)

echo .love file created successfully: %BUILD_DIR%\%GAME_NAME%.love
echo.

echo Step 2: Checking for LÖVE binaries...
echo ------------------------------------

:: Check if love.exe exists in the expected location
if exist "%BUILD_DIR%\love.exe" (
    echo LÖVE binaries found in build directory.
) else (
    echo LÖVE binaries not found. Downloading...
    
    :: Check if PowerShell is available for downloading
    where powershell >nul 2>&1
    if %ERRORLEVEL% == 0 (
        echo Downloading LÖVE %LOVE_VERSION% using PowerShell...
        powershell -Command "Invoke-WebRequest -Uri '%LOVE_URL%' -OutFile '%BUILD_DIR%\%LOVE_ZIP%'"
        
        if exist "%BUILD_DIR%\%LOVE_ZIP%" (
            echo Extracting LÖVE binaries...
            powershell -Command "Expand-Archive -Path '%BUILD_DIR%\%LOVE_ZIP%' -DestinationPath '%BUILD_DIR%' -Force"
            
            :: Move files from the nested directory to the build directory
            for /f %%i in ('dir /b "%BUILD_DIR%\love*win*"') do (
                xcopy /y /e "%BUILD_DIR%\%%i\*" "%BUILD_DIR%\"
                rmdir /s /q "%BUILD_DIR%\%%i"
            )
            
            :: Clean up the zip file
            del "%BUILD_DIR%\%LOVE_ZIP%"
        ) else (
            echo Failed to download LÖVE binaries.
            echo Please download manually from https://love2d.org/ and extract to %BUILD_DIR%
            goto :error
        )
    ) else (
        echo PowerShell not available for downloading.
        echo Please download LÖVE %LOVE_VERSION% manually from https://love2d.org/
        echo Extract the files to %BUILD_DIR%
        goto :error
    )
)

echo.
echo Step 3: Creating standalone executable...
echo ---------------------------------------

:: Combine love.exe with the .love file to create a standalone executable
if exist "%BUILD_DIR%\love.exe" (
    echo Creating standalone executable...
    copy /b "%BUILD_DIR%\love.exe"+"%BUILD_DIR%\%GAME_NAME%.love" "%BUILD_DIR%\%GAME_NAME%.exe"
    
    if exist "%BUILD_DIR%\%GAME_NAME%.exe" (
        echo Standalone executable created successfully: %BUILD_DIR%\%GAME_NAME%.exe
    ) else (
        echo Failed to create standalone executable!
        goto :error
    )
) else (
    echo love.exe not found in build directory!
    goto :error
)

echo.
echo Step 4: Finalizing package...
echo ---------------------------

:: Create a distribution directory
set DIST_DIR=%BUILD_DIR%\%GAME_NAME%-win64
if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"

:: Copy the executable and required DLLs
copy "%BUILD_DIR%\%GAME_NAME%.exe" "%DIST_DIR%\"
copy "%BUILD_DIR%\*.dll" "%DIST_DIR%\"
copy "%BUILD_DIR%\license.txt" "%DIST_DIR%\" 2>nul

echo.
echo Build completed successfully!
echo.
echo Your game has been packaged for Windows in:
echo %DIST_DIR%
echo.
echo This folder contains everything needed to run the game on Windows.
echo You can zip this folder and distribute it to users.
echo.
echo Thank you for using Square Golf Windows Build Script!
goto :end

:error
echo.
echo Build process encountered an error.
echo Please check the error messages above.
echo.

:end
pause
