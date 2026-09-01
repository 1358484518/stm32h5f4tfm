@echo off
rem Shared Windows setup for STM32H5F4 TF-M bats.
rem Caller may set H5F4_PORT (SWD or JLINK) and H5F4_SN.
rem On success: TFM_BL2 / TFM_S_SIGNED / TFM_S_NS_SIGNED / TFM_NS_SIGNED
rem             H5F4_CONNECT / H5F4_CONNECT_HP / PYCMD
rem Do not use internal subroutines here: that can close tfm_update.bat
rem before its pause when this file is invoked with CALL.
call "%~dp0h5f4_env.bat"
set "H5F4_SETUP_RC=0"
set "TFM_BL2="
set "TFM_S_SIGNED="
set "TFM_S_NS_SIGNED="
set "TFM_NS_SIGNED="
set "TFM_ERROR="
set "TFM_STATUS="
set "TFM_UPDATE_SH="
set "TFM_REPO="
set "PYCMD="
set "LOCATE_OUT=%TEMP%\h5f4_locate.txt"

if not defined H5F4_PORT set "H5F4_PORT=SWD"
set "H5F4_SN_OPT="
if defined H5F4_SN set "H5F4_SN_OPT=sn=%H5F4_SN%"

where STM32_Programmer_CLI >nul 2>&1
if errorlevel 1 (
    echo [FAIL] STM32_Programmer_CLI not found
    echo        Install STM32CubeProgrammer and add its bin directory to PATH.
    set "H5F4_SETUP_RC=1"
    exit /b 1
)
for /f "delims=" %%I in ('where STM32_Programmer_CLI') do (
    echo [ok]   STM32_Programmer_CLI = %%I
    goto :cli_found
)
:cli_found

set "PYCMD="
python -c "import sys; raise SystemExit(0 if sys.version_info[0]>=3 else 1)" >nul 2>&1
if not errorlevel 1 set "PYCMD=python"
if not defined PYCMD python3 -c "import sys; raise SystemExit(0 if sys.version_info[0]>=3 else 1)" >nul 2>&1
if not defined PYCMD if not errorlevel 1 set "PYCMD=python3"
if not defined PYCMD py -3 -c "import sys; raise SystemExit(0 if sys.version_info[0]>=3 else 1)" >nul 2>&1
if not defined PYCMD if not errorlevel 1 set "PYCMD=py -3"

if defined PYCMD (
    echo [ok]   python = %PYCMD%
    echo [info] locate H5F4 images
    echo CMD: %PYCMD% "%~dp0h5f4_win_images.py" --locate
    del "%LOCATE_OUT%" >nul 2>&1
    rem Do not use argparse here. Chinese Windows Python printed
    rem "此时不应有 。" and stopped before STATUS=OK.
    %PYCMD% "%~dp0h5f4_win_images.py" --locate > "%LOCATE_OUT%" 2>&1
    goto :parse_locate
)

echo [info] Python 3 not on PATH, try PowerShell to locate images
where powershell >nul 2>&1
if errorlevel 1 (
    echo [FAIL] Python 3 not found. Install Python 3 and add it to PATH
    echo        ^(needed to verify H5F4BL2 / H5F4SWP2 in bl2.bin^).
    set "H5F4_SETUP_RC=1"
    exit /b 1
)
echo [ok]   using PowerShell
del "%LOCATE_OUT%" >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0h5f4_win_images.ps1" locate "%LOCATE_OUT%" 2> "%LOCATE_OUT%.err"

:parse_locate
if not exist "%LOCATE_OUT%" (
    echo [FAIL] image locate produced no output
    type "%LOCATE_OUT%.err" 2>nul
    set "H5F4_SETUP_RC=1"
    exit /b 1
)
for /f "usebackq tokens=1* delims==" %%A in ("%LOCATE_OUT%") do (
    if /i "%%A"=="STATUS" set "TFM_STATUS=%%B"
    if /i "%%A"=="ERROR" set "TFM_ERROR=%%B"
    if /i "%%A"=="BL2" set "TFM_BL2=%%B"
    if /i "%%A"=="S_SIGNED" set "TFM_S_SIGNED=%%B"
    if /i "%%A"=="S_NS_SIGNED" set "TFM_S_NS_SIGNED=%%B"
    if /i "%%A"=="NS_SIGNED" set "TFM_NS_SIGNED=%%B"
    if /i "%%A"=="UPDATE_SH" set "TFM_UPDATE_SH=%%B"
    if /i "%%A"=="REPO" set "TFM_REPO=%%B"
)
if /i not "%TFM_STATUS%"=="OK" (
    echo [FAIL] %TFM_ERROR%
    echo ----- locate stdout -----
    type "%LOCATE_OUT%"
    echo ----- locate stderr -----
    type "%LOCATE_OUT%.err" 2>nul
    echo -----
    echo        Put bl2.bin / tfm_s_signed.bin / tfm_ns_signed.bin next to this bat,
    echo        or keep trusted-firmware-m\build_s\api_ns\bin from ./buildtfm.sh
    set "H5F4_SETUP_RC=1"
    exit /b 1
)
echo [ok]   BL2        %TFM_BL2%
if defined TFM_S_SIGNED echo [ok]   S          %TFM_S_SIGNED%
if defined TFM_S_NS_SIGNED echo [ok]   S+NS       %TFM_S_NS_SIGNED%
if defined TFM_NS_SIGNED echo [ok]   NS         %TFM_NS_SIGNED%
if defined TFM_UPDATE_SH echo [ok]   TFM_UPDATE %TFM_UPDATE_SH%

set "H5F4_CONNECT=-c port=%H5F4_PORT% ap=1 %H5F4_SN_OPT% mode=UR"
set "H5F4_CONNECT_HP=-c port=%H5F4_PORT% ap=1 %H5F4_SN_OPT% mode=HotPlug"
echo [info] connect = %H5F4_CONNECT%
exit /b 0
