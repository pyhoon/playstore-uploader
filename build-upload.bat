@echo off
setlocal EnableExtensions

rem Build a B4A app bundle and upload it to Google Play.
rem Copy this file into the B4A project folder, next to the .b4a file,
rem and edit the settings below.

set "BUILDER=C:\Program Files\B4X\B4A\B4ABuilder.exe"
set "JAVA=C:\Java\jdk-19.0.2\bin\java.exe"
set "TOOL=C:\tools\aabtool.jar"
set "PACKAGE=com.example.app"
set "KEY=%USERPROFILE%\keys\google-key.json"
set "TRACK=internal"
set "STATUS=completed"
set "OBFUSCATE=False"

set "BASE=%~dp0"
set "BASE=%BASE:~0,-1%"
set "LOG=%BASE%\build-upload.log"

if not exist "%BUILDER%" goto :bad_config
if not exist "%JAVA%" goto :bad_config
if not exist "%TOOL%" goto :bad_config
if not exist "%KEY%" goto :bad_config

set "PROJ="
for %%F in ("%BASE%\*.b4a") do set "PROJ=%%~nF"
if not defined PROJ (
    echo ERROR: No .b4a file found in "%BASE%".
    exit /b 1
)

if not exist "%BASE%\Objects" mkdir "%BASE%\Objects"

echo Building %PROJ%.aab ...
call "%BUILDER%" -Task=BuildBundle -BaseFolder="%BASE%" -Obfuscate=%OBFUSCATE% > "%LOG%" 2>&1
if errorlevel 1 goto :failed

set "AAB=%BASE%\Objects\%PROJ%.aab"
if not exist "%AAB%" (
    echo ERROR: Bundle not found: "%AAB%" >> "%LOG%"
    goto :failed
)

echo Uploading to %TRACK% ...
call "%JAVA%" -jar "%TOOL%" --app-bundle "%AAB%" --application-package "%PACKAGE%" --secret-file "%KEY%" --track "%TRACK%" --status "%STATUS%" >> "%LOG%" 2>&1
if errorlevel 1 goto :failed

rem aabtool exits 0 even when the upload fails, so check its success marker.
findstr /C:"Done: App Bundle uploaded and edit committed." "%LOG%" >nul
if errorlevel 1 goto :failed

type "%LOG%"
echo.
echo Build and upload completed.
exit /b 0

:failed
echo.
echo ERROR: Build or upload failed.
echo Log: "%LOG%"
type "%LOG%"
start "" notepad "%LOG%"
exit /b 1

:bad_config
echo ERROR: Check BUILDER, JAVA, TOOL and KEY at the top of this file.
exit /b 1
