@echo off
rem Shared Windows setup for STM32H5F4 TF-M bats.
rem Caller may set H5F4_PORT (SWD or JLINK) and H5F4_SN.
rem On success: TFM_BL2 / TFM_S_SIGNED / TFM_S_NS_SIGNED / TFM_NS_SIGNED
rem             H5F4_CONNECT / H5F4_CONNECT_HP / PYCMD
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
set "CUBEPROG="

if not defined H5F4_PORT set "H5F4_PORT=SWD"
set "H5F4_SN_OPT="
if defined H5F4_SN set "H5F4_SN_OPT=sn=%H5F4_SN%"

if exist "D:\ST\STM32CubeProgrammer\bin\STM32_Programmer_CLI.exe" (
    set "CUBEPROG=D:\ST\STM32CubeProgrammer\bin"
)
if not defined CUBEPROG if exist "%ProgramFiles%\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin\STM32_Programmer_CLI.exe" (
    set "CUBEPROG=%ProgramFiles%\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin"
)
if not defined CUBEPROG if exist "%ProgramFiles(x86)%\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin\STM32_Programmer_CLI.exe" (
    set "CUBEPROG=%ProgramFiles(x86)%\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin"
)
if not defined CUBEPROG if exist "C:\Program Files\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin\STM32_Programmer_CLI.exe" (
    set "CUBEPROG=C:\Program Files\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin"
)
if defined CUBEPROG (
    echo [info] CubeProgrammer bin = %CUBEPROG%
    set "PATH=%CUBEPROG%;%PATH%"
)
for /d %%D in ("%ProgramFiles%\SEGGER\JLink*") do (
    if exist "%%~D\JLinkARM.dll" set "PATH=%%~D;%PATH%"
)
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

where python >nul 2>&1 && set "PYCMD=python"
if not defined PYCMD where python3 >nul 2>&1 && set "PYCMD=python3"
if not defined PYCMD where py >nul 2>&1 && set "PYCMD=py -3"
if not defined PYCMD (
    echo [FAIL] Python 3 not found. Add python to PATH ^(needed to verify H5F4BL2 markers^).
    set "H5F4_SETUP_RC=1"
    exit /b 1
)
echo [ok]   python = %PYCMD%

echo [info] locate H5F4 images
for /f "usebackq tokens=1* delims==" %%A in (`%PYCMD% "%~dp0h5f4_win_images.py" locate`) do (
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
