@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1
title Emergency Nomad — USB Install

:: ================================================================== paths
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "TOOLS=%SCRIPT_DIR%\tools"
set "DECLARATION=%SCRIPT_DIR%\DECLARATION.md"
set "ON_DEVICE_INSTALL=%TOOLS%\on-device-install.sh"

set "DEVICE_STAGING=/data/local/tmp/emergency-nomad-staging"
set "DEVICE_RUNTIME=/data/local/tmp/emergency-nomad"
set "DAEMON_PORT=1234"
set "ADB_SERIAL="
set "STORAGE_PROFILE="
set "MODE=install"
set "HEADLESS=0"
set "AUTOYES=0"

:: ================================================================== parse args
set "BUNDLE_ZIP="
:parse_args
if "%~1"=="" goto args_done
if /i "%~1"=="--restart"  (set "MODE=restart" & shift & goto parse_args)
if /i "%~1"=="--headless" (set "HEADLESS=1"   & shift & goto parse_args)
if /i "%~1"=="--yes"      (set "AUTOYES=1"    & shift & goto parse_args)
if /i "%~1"=="-y"         (set "AUTOYES=1"    & shift & goto parse_args)
if /i "%~1"=="-s"         (set "ADB_SERIAL=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="-p"         (set "STORAGE_PROFILE=%~2" & shift & shift & goto parse_args)
if /i "%~1"=="-h"         goto usage
set "BUNDLE_ZIP=%~1"
shift
goto parse_args
:args_done

if "%MODE%"=="restart" goto preflight
if "%BUNDLE_ZIP%"=="" (
    echo error: bundle.zip path required >&2
    goto usage
)
if not exist "%BUNDLE_ZIP%" (
    echo error: file not found: %BUNDLE_ZIP% >&2
    exit /b 1
)
goto preflight

:usage
echo.
echo Usage:
echo   usb-push.bat [-s SERIAL] [-p PROFILE] [--headless] bundle.zip
echo   usb-push.bat --restart [-s SERIAL] [--headless]
echo.
echo Options:
echo   -s SERIAL    Select device when multiple connected
echo   -p PROFILE   Storage profile (full, reduced, volatile)
echo   --headless   Forward port to this PC (broken screen)
echo   --restart    Relaunch daemon only
echo   --yes, -y    Skip consent prompt
echo   -h           Show this help
echo.
exit /b 0

:: ================================================================== preflight
:preflight
echo.
echo --- preflight ---
echo.

:: Find adb: bundled or PATH
set "ADB="
if exist "%TOOLS%\platform-tools\adb.exe" (
    set "ADB=%TOOLS%\platform-tools\adb.exe"
) else (
    where adb >nul 2>&1
    if !errorlevel!==0 (
        for /f "delims=" %%a in ('where adb') do set "ADB=%%a"
    )
)
if "%ADB%"=="" (
    echo error: adb not found >&2
    echo.
    echo Download Android platform-tools from:
    echo   https://developer.android.com/studio/releases/platform-tools
    echo Extract into: %TOOLS%\platform-tools\
    exit /b 1
)
echo adb: %ADB%

set "SERVICE_APK="
if exist "%SCRIPT_DIR%\tools\nomad-service.apk" set "SERVICE_APK=%SCRIPT_DIR%\tools\nomad-service.apk"
if exist "%SCRIPT_DIR%\apk\nomad-service.apk" set "SERVICE_APK=%SCRIPT_DIR%\apk\nomad-service.apk"

:: Check tar (built-in Windows 10+)
where tar >nul 2>&1
if errorlevel 1 (
    echo error: tar not found — requires Windows 10 or later >&2
    exit /b 1
)
echo tar: found

if "%MODE%"=="restart" goto detect_device

echo bundle: %BUNDLE_ZIP%
echo.

:: ================================================================== detect device
:detect_device
echo --- device ---
echo.

:: Count authorized devices
set "DEVICE_COUNT=0"
for /f "tokens=1,2" %%a in ('"%ADB%" devices') do (
    if "%%b"=="device" (
        set /a DEVICE_COUNT+=1
        if not defined FIRST_SERIAL set "FIRST_SERIAL=%%a"
    )
)

if %DEVICE_COUNT%==0 (
    echo error: no ADB device connected >&2
    echo Ensure USB debugging is enabled and the device is plugged in. >&2
    exit /b 1
)

if %DEVICE_COUNT% gtr 1 if "%ADB_SERIAL%"=="" (
    echo error: multiple devices — use -s SERIAL >&2
    "%ADB%" devices
    exit /b 1
)

if "%ADB_SERIAL%"=="" set "ADB_SERIAL=%FIRST_SERIAL%"

:: Query device info
for /f "delims=" %%v in ('"%ADB%" -s %ADB_SERIAL% shell getprop ro.product.cpu.abi') do set "DEVICE_ABI=%%v"
for /f "delims=" %%v in ('"%ADB%" -s %ADB_SERIAL% shell getprop ro.build.version.sdk') do set "DEVICE_API=%%v"
for /f "delims=" %%v in ('"%ADB%" -s %ADB_SERIAL% shell getprop ro.product.model') do set "DEVICE_MODEL=%%v"

:: Strip carriage returns
set "DEVICE_ABI=%DEVICE_ABI: =%"
set "DEVICE_API=%DEVICE_API: =%"

echo device: %ADB_SERIAL%
echo model:  %DEVICE_MODEL%
echo abi:    %DEVICE_ABI%
echo api:    %DEVICE_API%
echo.

if "%MODE%"=="restart" goto restart_mode

:: ================================================================== temp dir
set "TMPDIR=%TEMP%\emergency-nomad-%RANDOM%"
mkdir "%TMPDIR%" 2>nul

:: Extract bootstrap.json
tar -xf "%BUNDLE_ZIP%" -C "%TMPDIR%" bootstrap.json 2>nul
if not exist "%TMPDIR%\bootstrap.json" (
    echo error: bundle does not contain bootstrap.json >&2
    goto cleanup
)

:: ================================================================== compatibility (PowerShell inline)
for /f "delims=" %%v in ('powershell -NoProfile -Command "(Get-Content '%TMPDIR%\bootstrap.json' | ConvertFrom-Json).compatibility.android_api_min"') do set "API_MIN=%%v"

if %DEVICE_API% lss %API_MIN% (
    echo error: device API %DEVICE_API% ^< minimum %API_MIN% >&2
    goto cleanup_fail
)

for /f "delims=" %%v in ('powershell -NoProfile -Command "$m=(Get-Content '%TMPDIR%\bootstrap.json' | ConvertFrom-Json); if($m.compatibility.supported_abis -contains '%DEVICE_ABI%'){'yes'}else{'no'}"') do set "ABI_OK=%%v"

if not "%ABI_OK%"=="yes" (
    echo error: device ABI %DEVICE_ABI% not supported >&2
    goto cleanup_fail
)

echo compatibility: api %DEVICE_API% ^>= %API_MIN%, abi %DEVICE_ABI% supported

:: ================================================================== resolve install plan (PowerShell)
echo.
echo --- resolve install plan ---
echo.

set "PLAN_PROFILE=%STORAGE_PROFILE%"
if "%PLAN_PROFILE%"=="" set "PLAN_PROFILE="

powershell -NoProfile -File "%TOOLS%\resolve-install-plan.ps1" "%TMPDIR%\bootstrap.json" "%DEVICE_ABI%" "%PLAN_PROFILE%" > "%TMPDIR%\install-plan.txt"
if errorlevel 1 (
    echo error: install plan resolve failed >&2
    goto cleanup_fail
)

for /f "usebackq tokens=*" %%l in (`findstr /v /b "# " "%TMPDIR%\install-plan.txt" ^| findstr /v /r "^$"`) do (
    echo   %%l
)
echo.

:: ================================================================== declaration + consent
echo ============================================================
if exist "%DECLARATION%" (
    type "%DECLARATION%"
) else (
    echo (DECLARATION.md not found)
)
echo ============================================================
echo.
echo target:  %DEVICE_MODEL% (%ADB_SERIAL%)
echo abi:     %DEVICE_ABI%
echo api:     %DEVICE_API%
echo bundle:  %BUNDLE_ZIP%
echo.
echo THIS WILL:
echo   - overwrite any previous emergency-nomad installation
echo   - use storage space on the device
if defined SERVICE_APK (
    echo   - install the bundled helper APK ^(com.emergency.nomad^)
) else (
    echo   - install only the runtime tree ^(no helper APK bundled in this folder^)
)
echo   - launch a daemon on 127.0.0.1:%DAEMON_PORT%
echo.
echo THIS WILL NOT:
echo   - use the network
echo   - root the device
echo   - modify bootloader, recovery, or the system partition
echo   - change radios or airplane-mode state for you
echo.

if "%AUTOYES%"=="1" (
    echo Proceed? [y/N] y  (--yes flag)
) else (
    set /p "CONFIRM=Proceed? [y/N] "
    if /i not "!CONFIRM!"=="y" (
        echo Aborted by operator.
        goto cleanup
    )
)

:: ================================================================== assemble runtime tree
echo.
echo --- assembling runtime tree ---
echo.

set "LOCAL_RUNTIME=%TMPDIR%\staging\runtime"
mkdir "%LOCAL_RUNTIME%\config" 2>nul

:: Generate access token (12 hex chars)
for /f "delims=" %%t in ('powershell -NoProfile -Command "[System.BitConverter]::ToString([byte[]]::new(6) -replace '-','').Substring(0,12).ToLower(); $b=New-Object byte[] 6; (New-Object Security.Cryptography.RNGCryptoServiceProvider).GetBytes($b); -join($b|ForEach-Object{$_.ToString('x2')})"') do set "ACCESS_TOKEN=%%t"

echo access_token=%ACCESS_TOKEN%>> "%LOCAL_RUNTIME%\config\runtime.conf"
echo access token: %ACCESS_TOKEN%

:: Process install plan line by line
for /f "usebackq tokens=*" %%l in ("%TMPDIR%\install-plan.txt") do (
    set "LINE=%%l"
    call :process_line
)

echo.
goto push_to_device

:process_line
:: Handle config lines
echo !LINE! | findstr /b "# config: " >nul 2>&1
if not errorlevel 1 (
    set "CFG=!LINE:# config: =!"
    echo !CFG!>> "%LOCAL_RUNTIME%\config\runtime.conf"
    exit /b
)
:: Skip comments and empty
echo !LINE! | findstr /b "#" >nul 2>&1 && exit /b
if "!LINE!"=="" exit /b

:: Parse: ACTION SOURCE_PATH DEST_SUBDIR SHA256
for /f "tokens=1,2,3,4" %%a in ("!LINE!") do (
    set "ACTION=%%a"
    set "SRC_PATH=%%b"
    set "DEST_SUB=%%c"
    set "CHECKSUM=%%d"
)

set "DEST_DIR=%LOCAL_RUNTIME%\!DEST_SUB!"
if not exist "!DEST_DIR!" mkdir "!DEST_DIR!"

echo [!ACTION!] !SRC_PATH! -^> !DEST_SUB!

:: Extract from zip
mkdir "%TMPDIR%\zip_extract" 2>nul
tar -xf "%BUNDLE_ZIP%" -C "%TMPDIR%\zip_extract" "!SRC_PATH!" 2>nul
set "EXTRACTED=%TMPDIR%\zip_extract\!SRC_PATH!"

if not exist "!EXTRACTED!" (
    echo error: !SRC_PATH! not found in bundle >&2
    exit /b 1
)

:: Verify SHA-256
if not "!CHECKSUM!"=="-" (
    for /f "tokens=*" %%h in ('certutil -hashfile "!EXTRACTED!" SHA256 ^| findstr /v "hash CertUtil"') do (
        set "ACTUAL_HASH=%%h"
        set "ACTUAL_HASH=!ACTUAL_HASH: =!"
    )
    if /i not "!ACTUAL_HASH!"=="!CHECKSUM!" (
        echo error: checksum mismatch for !SRC_PATH! >&2
        exit /b 1
    )
    echo   sha256: ok
)

:: Process action
if "!ACTION!"=="extract" (
    tar -xf "!EXTRACTED!" -C "!DEST_DIR!"
)
if "!ACTION!"=="copy" (
    for %%f in ("!EXTRACTED!") do copy /y "!EXTRACTED!" "!DEST_DIR!\%%~nxf" >nul
)
if "!ACTION!"=="seed" (
    for %%f in ("!EXTRACTED!") do copy /y "!EXTRACTED!" "!DEST_DIR!\%%~nxf" >nul
)

:: Clean per-file temp
rmdir /s /q "%TMPDIR%\zip_extract" 2>nul
exit /b

:: ================================================================== push to device
:push_to_device
echo --- pushing to device ---
echo.

"%ADB%" -s %ADB_SERIAL% shell "rm -rf '%DEVICE_STAGING%' && mkdir -p '%DEVICE_STAGING%'"

echo pushing runtime tree...
"%ADB%" -s %ADB_SERIAL% push "%LOCAL_RUNTIME%" "%DEVICE_STAGING%/runtime"

echo pushing installer...
"%ADB%" -s %ADB_SERIAL% push "%ON_DEVICE_INSTALL%" "%DEVICE_STAGING%/on-device-install.sh"

echo.

:: ================================================================== on-device install
echo --- running on-device install ---
echo.

"%ADB%" -s %ADB_SERIAL% shell "sh '%DEVICE_STAGING%/on-device-install.sh'"

echo.

:: ================================================================== install APK
echo --- installing service APK ---
echo.

if defined SERVICE_APK (
    echo apk: !SERVICE_APK!
    "%ADB%" -s %ADB_SERIAL% install -r "!SERVICE_APK!" 2>nul | findstr /i "success"
) else (
    echo warning: nomad-service.apk not found, daemon won't survive reboot
)
echo.

:: ================================================================== launch daemon
:launch_daemon
echo --- launching daemon ---
echo.

"%ADB%" -s %ADB_SERIAL% shell "pkill -f '[n]omad-daemon' 2>/dev/null || true"
"%ADB%" -s %ADB_SERIAL% shell "am force-stop com.emergency.nomad 2>/dev/null || true"
timeout /t 1 /nobreak >nul

:: Try launching via APK Service (survives reboot + watchdog)
set "SERVICE_LAUNCH=0"
for /f "delims=" %%p in ('"%ADB%" -s %ADB_SERIAL% shell "pm list packages 2>/dev/null" ^| findstr "com.emergency.nomad"') do set "SERVICE_LAUNCH=1"

if "%SERVICE_LAUNCH%"=="1" (
    "%ADB%" -s %ADB_SERIAL% shell "am start -n com.emergency.nomad/.StartActivity" >nul 2>&1
    echo started via Android Service (survives reboot)
) else (
    "%ADB%" -s %ADB_SERIAL% shell "sh -c 'setsid %DEVICE_RUNTIME%/daemon/nomad-daemon </dev/null >/dev/null 2>&1 & exit 0'"
    echo started directly (will NOT survive reboot)
)

:: Wait for watchdog + daemon bind
timeout /t 5 /nobreak >nul

:: Verify
set "DAEMON_PID="
for /f "delims=" %%p in ('"%ADB%" -s %ADB_SERIAL% shell "pgrep -f [n]omad-daemon 2>/dev/null | head -1"') do set "DAEMON_PID=%%p"
set "DAEMON_PID=%DAEMON_PID: =%"

if defined DAEMON_PID (
    echo daemon running: PID %DAEMON_PID% on port %DAEMON_PORT%
) else (
    echo warning: daemon may not have started
)
echo.

:: ================================================================== open browser / port forward
if "%HEADLESS%"=="1" (
    echo --- headless mode: port forward ---
    echo.
    "%ADB%" -s %ADB_SERIAL% forward tcp:%DAEMON_PORT% tcp:%DAEMON_PORT%
    echo Open on this computer:
    echo.
    echo   http://127.0.0.1:%DAEMON_PORT%/s/%ACCESS_TOKEN%
    echo.
    start "" "http://127.0.0.1:%DAEMON_PORT%/s/%ACCESS_TOKEN%"
) else (
    echo --- opening browser on device ---
    echo.
    "%ADB%" -s %ADB_SERIAL% shell "am start -a android.intent.action.VIEW -d 'http://127.0.0.1:%DAEMON_PORT%/s/%ACCESS_TOKEN%' 2>/dev/null || true"
    echo Browser opened on device.
    echo Bookmark this address:
    echo.
    echo   http://127.0.0.1:%DAEMON_PORT%/s/%ACCESS_TOKEN%
    echo.
    echo You can disconnect the USB cable now.
)

echo.
echo --- done ---
echo.
echo Bootstrap complete: %DEVICE_MODEL% (%ADB_SERIAL%)
echo.
echo Your address (save this):
echo   http://127.0.0.1:%DAEMON_PORT%/s/%ACCESS_TOKEN%
echo.
goto cleanup

:: ================================================================== restart mode
:restart_mode
echo --- restarting daemon ---
echo.

:: Read token from device
for /f "delims=" %%t in ('"%ADB%" -s %ADB_SERIAL% shell "cat %DEVICE_RUNTIME%/config/runtime.conf 2>/dev/null" ^| findstr "access_token="') do (
    set "TOKEN_LINE=%%t"
)
if defined TOKEN_LINE (
    for /f "tokens=2 delims==" %%v in ("!TOKEN_LINE!") do set "ACCESS_TOKEN=%%v"
)

goto launch_daemon

:: ================================================================== cleanup
:cleanup
if defined TMPDIR if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%" 2>nul
exit /b 0

:cleanup_fail
if defined TMPDIR if exist "%TMPDIR%" rmdir /s /q "%TMPDIR%" 2>nul
exit /b 1
