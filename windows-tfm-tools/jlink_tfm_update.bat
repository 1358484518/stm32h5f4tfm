@echo off
rem ****************************************************************************
rem  STM32H5F4 TF-M flash after J-Link regression (Windows)
rem
rem  WRP names are WRPSG11/12/21/22 (not H573 WRPSGn1).
rem  J-Link programs the 0x08000000 flash window. Hex files that use the
rem  secure alias 0x0Cxxxxxx are remapped across the full 4 MB
rem  (0x0C000000-0x0C3FFFFF -> 0x08000000-0x083FFFFF).
rem ****************************************************************************
setlocal EnableExtensions EnableDelayedExpansion

set "EXIT_CODE=0"
set "FAILED_STEP="
set "FLASHED=0"
set "SKIP_NS=0"
set "DO_REG=1"
set "H5F4_PORT=JLINK"
set "H5F4_SN="
call "%~dp0h5f4_env.bat"

if /i "%~1"=="-h" goto :usage
if /i "%~1"=="/?" goto :usage

:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="images-only" (
    set "DO_REG=0"
    shift
    goto :parse_args
)
if /i "%~1"=="skip-erase" (
    set "DO_REG=0"
    shift
    goto :parse_args
)
set "H5F4_SN=%~1"
shift
goto :parse_args
:args_done

echo.
echo ============================================================
echo  STM32H5F4  jlink_tfm_update.bat
echo  rev:  %H5F4_REV%
echo  cwd:  %CD%
echo  J-Link: program 0x08 alias as .bin, SECWM open while flashing
echo ============================================================
echo.

call "%~dp0h5f4_setup.bat"
if errorlevel 1 (
    set "FAILED_STEP=locate images / STM32_Programmer_CLI"
    set "EXIT_CODE=1"
    goto :finish
)

echo.
echo Flash map ^(NS alias for J-Link^):
echo   BL2  %H5F4_ADDR_BL2_NS%
echo   S    %H5F4_ADDR_S_NS%
echo   NS   %H5F4_ADDR_NS_NS%
echo.

if "%DO_REG%"=="1" (
    echo [1] Run J-Link regression
    echo ------------------------------------------------------------
    set "TFM_SKIP_PAUSE=1"
    if defined H5F4_SN (
        call "%~dp0jlink_regression.bat" jlink %H5F4_SN%
    ) else (
        call "%~dp0jlink_regression.bat" jlink
    )
    set "TFM_SKIP_PAUSE="
    if errorlevel 1 (
        echo [FAIL] regression failed, skip download
        set "FAILED_STEP=jlink_regression.bat"
        set "EXIT_CODE=1"
        goto :finish
    )
    echo [ok]   regression finished
    echo.
) else (
    echo [1] skip regression ^(images-only^)
    echo.
)

set "connect=%H5F4_CONNECT%"
set "connect_no_reset=%H5F4_CONNECT_HP%"

echo [2] Open SECWM ^(J-Link cannot program fully-secure 0x0C flash^)
echo CMD: STM32_Programmer_CLI %connect_no_reset% -ob %H5F4_SECWM_OPEN%
STM32_Programmer_CLI %connect_no_reset% -ob %H5F4_SECWM_OPEN%
if errorlevel 1 (
    echo [FAIL] could not open SECWM
    set "FAILED_STEP=open SECWM"
    set "EXIT_CODE=1"
    goto :finish
)
echo.

echo [3] Download
echo.

if defined TFM_S_SIGNED (
    call :flash_image "%TFM_S_SIGNED%" %H5F4_ADDR_S_NS% "S signed"
    if errorlevel 1 goto :finish
) else (
    call :flash_image "%TFM_S_NS_SIGNED%" %H5F4_ADDR_S_NS% "S+NS signed"
    if errorlevel 1 goto :finish
    set "SKIP_NS=1"
)

if "%SKIP_NS%"=="1" (
    echo [info] skip NS, already in concatenated S+NS
) else (
    if not defined TFM_NS_SIGNED (
        echo [FAIL] tfm_ns_signed.bin not found
        set "FAILED_STEP=no NS image"
        set "EXIT_CODE=1"
        goto :finish
    )
    call :flash_image "%TFM_NS_SIGNED%" %H5F4_ADDR_NS_NS% "NS signed"
    if errorlevel 1 goto :finish
)

call :flash_image "%TFM_BL2%" %H5F4_ADDR_BL2_NS% "BL2"
if errorlevel 1 goto :finish

if "%FLASHED%"=="0" (
    echo [FAIL] nothing downloaded
    set "FAILED_STEP=nothing downloaded"
    set "EXIT_CODE=1"
    goto :finish
)

echo [4] Restore full-bank SECWM 0-255
echo CMD: STM32_Programmer_CLI %connect_no_reset% -ob %H5F4_SECWM_FULL%
STM32_Programmer_CLI %connect_no_reset% -ob %H5F4_SECWM_FULL%
if errorlevel 1 (
    echo [FAIL] restore SECWM
    set "FAILED_STEP=restore SECWM"
    set "EXIT_CODE=1"
    goto :finish
)
echo [ok]   SECWM restored
echo.

echo [5] Reset MCU
echo ------------------------------------------------------------
echo CMD: STM32_Programmer_CLI %connect% -hardRst
STM32_Programmer_CLI %connect% -hardRst
if errorlevel 1 (
    echo [FAIL] reset failed
    set "FAILED_STEP=hardRst"
    set "EXIT_CODE=1"
    goto :finish
)
echo [ok]   reset done
echo.

echo ============================================================
echo  ALL STEPS OK  ^(%FLASHED% file(s) downloaded^)  port=JLINK
echo  UART 115200 USART1 PA9/PA10 must show H5F4BL2
echo ============================================================
goto :finish

:usage
echo Usage: jlink_tfm_update.bat [images-only] [J-Link SN]
echo J-Link uses 0x08 flash alias. Hex 0x0C addresses are remapped ^(4 MB^).
pause
exit /b 0

:flash_image
set "STEP_PATH=%~1"
set "STEP_ADDR=%~2"
set "STEP_DESC=%~3"
set "STEP_NAME=%~nx1"
set "EXT=%~x1"
if /i "%EXT%"==".hex" (
    call :remap_hex "%STEP_NAME%" "%STEP_PATH%"
    if errorlevel 1 exit /b 1
    set "STEP_PATH=!HEX_BIN!"
    set "STEP_ADDR=!HEX_LOAD!"
)
echo ------------------------------------------------------------
echo DOWNLOAD  %STEP_DESC%  [%STEP_NAME%]
echo FILE: %STEP_PATH%
echo ADDR: %STEP_ADDR%   ^(must be 0x08..., never 0x0C...^)
echo CMD:  STM32_Programmer_CLI %connect% -d "%STEP_PATH%" %STEP_ADDR%
echo ------------------------------------------------------------
echo %STEP_ADDR% | findstr /i /c:"0x0C" >nul
if not errorlevel 1 (
    echo [FAIL] refusing 0x0C alias on J-Link: %STEP_ADDR%
    set "FAILED_STEP=0x0C alias %STEP_NAME%"
    set "EXIT_CODE=1"
    exit /b 1
)
STM32_Programmer_CLI %connect% -d "%STEP_PATH%" %STEP_ADDR% > "%TEMP%\tfm_jlink_dl.txt" 2>&1
set "DLRC=%ERRORLEVEL%"
call :check_download
exit /b %ERRORLEVEL%

:remap_hex
if not defined PYCMD (
    echo [FAIL] J-Link hex remap needs Python 3. Use .bin files or install Python.
    set "FAILED_STEP=remap needs Python"
    set "EXIT_CODE=1"
    exit /b 1
)
set "HEX_BIN=%TEMP%\tfm_jlink_%~n1.bin"
set "HEX_ADDR_FILE=%HEX_BIN%.addr"
echo [info] hex -^> bin on 0x08 alias ^(4 MB remap^)
echo        in  %~2
echo        out %HEX_BIN%
%PYCMD% "%~dp0jlink_hex_ns_alias.py" -InFile "%~2" -OutFile "%HEX_BIN%"
if errorlevel 1 (
    echo [FAIL] hex to bin failed
    set "FAILED_STEP=remap %~1"
    set "EXIT_CODE=1"
    exit /b 1
)
if not exist "%HEX_BIN%" (
    echo [FAIL] bin not created
    set "FAILED_STEP=remap %~1"
    set "EXIT_CODE=1"
    exit /b 1
)
set "HEX_LOAD="
if exist "%HEX_ADDR_FILE%" set /p HEX_LOAD=<"%HEX_ADDR_FILE%"
echo [info] LOAD %HEX_LOAD%
echo %HEX_LOAD% | findstr /i /c:"0x0C" >nul
if not errorlevel 1 (
    echo [FAIL] converted address still 0x0C, will not program secure alias
    set "FAILED_STEP=remap still 0x0C"
    set "EXIT_CODE=1"
    exit /b 1
)
exit /b 0

:check_download
type "%TEMP%\tfm_jlink_dl.txt"
findstr /c:"0x0C038000" /c:"0x0C00E000" /c:"0x0C088000" /c:"0x0C090000" /c:"0x0C200000" /c:"0x0C258000" "%TEMP%\tfm_jlink_dl.txt" >nul
if not errorlevel 1 (
    echo.
    echo [FAIL] CubeProgrammer still used 0x0C alias. Need the H5F4 jlink remap.
    set "FAILED_STEP=download %STEP_NAME% still 0x0C"
    set "EXIT_CODE=1"
    exit /b 1
)
findstr /i /c:"Data mismatch" /c:"verification failed" /c:"Error: Download" /c:"Error: failed" /c:"No debug probe" /c:"Library not found" "%TEMP%\tfm_jlink_dl.txt" >nul
if not errorlevel 1 (
    echo.
    echo [FAIL] download %STEP_NAME%  ^(CubeProgrammer reported Error^)
    set "FAILED_STEP=download %STEP_NAME%"
    set "EXIT_CODE=1"
    exit /b 1
)
if not "%DLRC%"=="0" (
    echo.
    echo [FAIL] download %STEP_NAME%  exit=%DLRC%
    set "FAILED_STEP=download %STEP_NAME%"
    set "EXIT_CODE=1"
    exit /b 1
)
echo [ok]   %STEP_NAME% downloaded
echo.
set /a FLASHED+=1
exit /b 0

:finish
echo.
if not "%EXIT_CODE%"=="0" (
    echo ============================================================
    echo  FAILED at: %FAILED_STEP%
    echo ============================================================
) else (
    echo ============================================================
    echo  jlink_tfm_update Done
    echo ============================================================
)
echo Window stays open. Press any key to close.
pause
endlocal & exit /b %EXIT_CODE%
