@echo off
rem ****************************************************************************
rem  STM32H5F4 TF-M option-byte regression (Windows)
rem  Default probe: J-Link via CubeProgrammer  -c port=JLINK
rem  Leaves SECWM open so J-Link can program the 0x08 flash alias.
rem  Onboard ST-LINK only if first argument is stlink.
rem ****************************************************************************
if not defined H5F4_INNER (
    set "H5F4_INNER=1"
    cmd /c ""%~f0" %*"
    echo.
    echo Window stays open. Press any key to close.
    pause
    exit /b
)
setlocal EnableExtensions
set "FAILED_STEP="
set "EXIT_CODE=0"
set "PORT=JLINK"
set "SN_ARG="

if /i "%~1"=="stlink" (
    set "PORT=SWD"
    if not "%~2"=="" set "SN_ARG=%~2"
) else if /i "%~1"=="jlink" (
    set "PORT=JLINK"
    if not "%~2"=="" set "SN_ARG=%~2"
) else if /i "%~1"=="-h" (
    goto :usage
) else if /i "%~1"=="/?" (
    goto :usage
) else if not "%~1"=="" (
    set "SN_ARG=%~1"
)

call "%~dp0h5f4_env.bat"

echo.
echo ============================================================
echo  STM32H5F4  jlink_regression.bat  (OEM-iRoT)
echo  rev:  %H5F4_REV%
echo ============================================================
echo.

echo [1/8] Locate STM32_Programmer_CLI
where STM32_Programmer_CLI >nul 2>&1
if errorlevel 1 (
    echo [FAIL] STM32_Programmer_CLI not found
    set "FAILED_STEP=1/8 Locate STM32_Programmer_CLI"
    set "EXIT_CODE=1"
    goto :finish
)
for /f "delims=" %%I in ('where STM32_Programmer_CLI') do (
    echo [ok]   %%I
    goto :cli_found
)
:cli_found

set "sn_option="
if defined SN_ARG (
    set "sn_option=sn=%SN_ARG%"
    echo [info] probe SN = %SN_ARG%
) else (
    echo [info] using first probe ^(port=%PORT%^)
)
echo [info] connect = -c port=%PORT% ap=1 %sn_option% mode=UR

set "connect=-c port=%PORT% ap=1 %sn_option% mode=UR"
set "connect_no_reset=-c port=%PORT% ap=1 %sn_option% mode=HotPlug"
set "product_state=-ob %H5F4_PRODUCT_STATE%"
set "remove_bank1_protect=-ob SECWM1_STRT=255 SECWM1_END=0 WRPSG11=0xffffffff WRPSG12=0xffffffff"
set "remove_bank2_protect=-ob SECWM2_STRT=255 SECWM2_END=0 WRPSG21=0xffffffff WRPSG22=0xffffffff"
set "erase_all=-e all"
set "remove_hdp_protection=-ob %H5F4_HDP_OFF%"
set "default_ob1=-ob %H5F4_OB1%"
set "default_ob2=-ob %H5F4_SECWM_OPEN%"
set "boot_ube=-ob %H5F4_BOOT_UBE%"

echo.
echo [2/8] PRODUCT_STATE=0xED  TZEN=0xB4 ^(TrustZone ON^)
set "STEP_ID=2/8"
set "STEP_NAME=PRODUCT_STATE / TZEN"
set "CLI_ARGS=%connect% %product_state%"
call "%~dp0h5f4_run_cli.bat"
if errorlevel 1 goto :cli_fail

echo.
echo [3/8] Remove bank1 protection and erase all
set "STEP_ID=3/8"
set "STEP_NAME=Remove bank1 protect + erase"
set "CLI_ARGS=%connect% %remove_bank1_protect% %erase_all%"
call "%~dp0h5f4_run_cli.bat"
if errorlevel 1 goto :cli_fail

echo.
echo [4/8] Remove bank2 protection and erase all
set "STEP_ID=4/8"
set "STEP_NAME=Remove bank2 protect + erase"
set "CLI_ARGS=%connect% %remove_bank2_protect% %erase_all%"
call "%~dp0h5f4_run_cli.bat"
if errorlevel 1 goto :cli_fail

echo.
echo [5/8] Remove HDP protection
set "STEP_ID=5/8"
set "STEP_NAME=Remove HDP"
set "CLI_ARGS=%connect_no_reset% %remove_hdp_protection%"
call "%~dp0h5f4_run_cli.bat"
if errorlevel 1 goto :cli_fail

echo.
echo [6/8] Default OB1 : SECBOOTADD=0xC0100 ^(BL2^)
set "STEP_ID=6/8"
set "STEP_NAME=Default OB1 SECBOOTADD"
set "CLI_ARGS=%connect_no_reset% %default_ob1%"
call "%~dp0h5f4_run_cli.bat"
if errorlevel 1 goto :cli_fail

echo.
echo [7/8] Leave SECWM open so J-Link can program 0x08 flash
set "STEP_ID=7/8"
set "STEP_NAME=SECWM open for J-Link"
set "CLI_ARGS=%connect_no_reset% %default_ob2%"
call "%~dp0h5f4_run_cli.bat"
if errorlevel 1 goto :cli_fail

echo.
echo [8/8] BOOT_UBE=0xB4 ^(OEM-iRoT^)
set "STEP_ID=8/8"
set "STEP_NAME=BOOT_UBE OEM-iRoT"
set "CLI_ARGS=%connect_no_reset% %boot_ube%"
call "%~dp0h5f4_run_cli.bat"
if errorlevel 1 goto :cli_fail

echo.
echo [extra] Read option bytes
set "STEP_ID=extra"
set "STEP_NAME=Display option bytes"
set "CLI_ARGS=%connect_no_reset% -ob displ"
call "%~dp0h5f4_run_cli.bat"
if errorlevel 1 goto :cli_fail

echo.
echo ============================================================
echo  ALL STEPS OK   port=%PORT%
echo  STM32H5F4 OEM-iRoT: BOOT_UBE=0xB4  SECBOOTADD=0xC0100  TZEN=0xB4
echo  SECWM left open ^(STRT=255 END=0^) for J-Link 0x08 programming
echo ============================================================
goto :finish

:usage
echo Usage: jlink_regression.bat [jlink^|stlink] [SN]
echo Default is J-Link:  -c port=JLINK ap=1
echo H5F4: WRPSG11/12/21/22, SECWM 0-255.
pause
exit /b 0

:cli_fail
set "FAILED_STEP=%STEP_ID% %STEP_NAME%"
set "EXIT_CODE=1"
goto :finish

:finish
echo.
if not "%EXIT_CODE%"=="0" (
    echo ============================================================
    echo  FAILED at: %FAILED_STEP%
    echo ============================================================
) else (
    echo ============================================================
    echo  regression Done
    echo ============================================================
)
if /i "%TFM_SKIP_PAUSE%"=="1" endlocal & exit /b %EXIT_CODE%
if defined H5F4_INNER endlocal & exit /b %EXIT_CODE%
echo Window stays open. Press any key to close.
pause
endlocal & exit /b %EXIT_CODE%
