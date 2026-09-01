@echo off
rem Find TF-M images. Prefer .bin; if none, convert matching .hex to .bin.
rem Search cwd, this folder, then TF-M build output including build_s\bin
rem (git tracks bl2.hex there; api_ns\bin is gitignored).
rem Do not use CALL :label.

set "TFM_BL2="
set "TFM_S_SIGNED="
set "TFM_NS_SIGNED="
set "TFM_S_NS_SIGNED="
del "%TEMP%\h5f4_bl2.bin" >nul 2>&1
del "%TEMP%\h5f4_s.bin" >nul 2>&1
del "%TEMP%\h5f4_ns.bin" >nul 2>&1
del "%TEMP%\h5f4_sns.bin" >nul 2>&1
set "TFM_BL2_HEX="
set "TFM_S_HEX="
set "TFM_NS_HEX="
set "TFM_SNS_HEX="
set "H5F4_BIN_S=%~dp0..\trusted-firmware-m\build_s\api_ns\bin"
set "H5F4_BIN_S2=%~dp0..\trusted-firmware-m\build_s\bin"
set "H5F4_BIN_NS=%~dp0..\trusted-firmware-m\build_ns\bin"

echo [info] search bin then hex in:
echo        %CD%
echo        %~dp0
echo        %H5F4_BIN_S%
echo        %H5F4_BIN_S2%
echo        %H5F4_BIN_NS%

for %%D in ("%CD%" "%~dp0." "%H5F4_BIN_S%" "%H5F4_BIN_S2%" "%H5F4_BIN_NS%") do (
    if not defined TFM_BL2 if exist "%%~fD\bl2.bin" set "TFM_BL2=%%~fD\bl2.bin"
    if not defined TFM_S_SIGNED if exist "%%~fD\tfm_s_signed.bin" set "TFM_S_SIGNED=%%~fD\tfm_s_signed.bin"
    if not defined TFM_NS_SIGNED if exist "%%~fD\tfm_ns_signed.bin" set "TFM_NS_SIGNED=%%~fD\tfm_ns_signed.bin"
    if not defined TFM_S_NS_SIGNED if exist "%%~fD\tfm_s_ns_signed.bin" set "TFM_S_NS_SIGNED=%%~fD\tfm_s_ns_signed.bin"
)
for %%D in ("%CD%" "%~dp0." "%H5F4_BIN_S%" "%H5F4_BIN_S2%" "%H5F4_BIN_NS%") do (
    if not defined TFM_BL2 if not defined TFM_BL2_HEX if exist "%%~fD\bl2.hex" set "TFM_BL2_HEX=%%~fD\bl2.hex"
    if not defined TFM_S_SIGNED if not defined TFM_S_HEX if exist "%%~fD\tfm_s_signed.hex" set "TFM_S_HEX=%%~fD\tfm_s_signed.hex"
    if not defined TFM_NS_SIGNED if not defined TFM_NS_HEX if exist "%%~fD\tfm_ns_signed.hex" set "TFM_NS_HEX=%%~fD\tfm_ns_signed.hex"
    if not defined TFM_S_NS_SIGNED if not defined TFM_SNS_HEX if exist "%%~fD\tfm_s_ns_signed.hex" set "TFM_SNS_HEX=%%~fD\tfm_s_ns_signed.hex"
)

if not defined TFM_BL2 if exist "%~dp0..\trusted-firmware-m\build_s\bin\bl2.hex" set "TFM_BL2_HEX=%~dp0..\trusted-firmware-m\build_s\bin\bl2.hex"
if not defined TFM_S_NS_SIGNED if exist "%~dp0..\trusted-firmware-m\build_ns\bin\tfm_s_ns_signed.hex" set "TFM_SNS_HEX=%~dp0..\trusted-firmware-m\build_ns\bin\tfm_s_ns_signed.hex"

if not defined TFM_BL2 if defined TFM_BL2_HEX if defined PYCMD %PYCMD% "%~dp0h5f4_win_images.py" hex2bin "%TFM_BL2_HEX%" "%TEMP%\h5f4_bl2.bin"
if not defined TFM_BL2 if exist "%TEMP%\h5f4_bl2.bin" if defined TFM_BL2_HEX set "TFM_BL2=%TEMP%\h5f4_bl2.bin"
if not defined TFM_BL2 if defined TFM_BL2_HEX set "TFM_BL2=%TFM_BL2_HEX%"

if not defined TFM_S_SIGNED if defined TFM_S_HEX if defined PYCMD %PYCMD% "%~dp0h5f4_win_images.py" hex2bin "%TFM_S_HEX%" "%TEMP%\h5f4_s.bin"
if not defined TFM_S_SIGNED if exist "%TEMP%\h5f4_s.bin" if defined TFM_S_HEX set "TFM_S_SIGNED=%TEMP%\h5f4_s.bin"
if not defined TFM_S_SIGNED if defined TFM_S_HEX set "TFM_S_SIGNED=%TFM_S_HEX%"

if not defined TFM_NS_SIGNED if defined TFM_NS_HEX if defined PYCMD %PYCMD% "%~dp0h5f4_win_images.py" hex2bin "%TFM_NS_HEX%" "%TEMP%\h5f4_ns.bin"
if not defined TFM_NS_SIGNED if exist "%TEMP%\h5f4_ns.bin" if defined TFM_NS_HEX set "TFM_NS_SIGNED=%TEMP%\h5f4_ns.bin"
if not defined TFM_NS_SIGNED if defined TFM_NS_HEX set "TFM_NS_SIGNED=%TFM_NS_HEX%"

if not defined TFM_S_NS_SIGNED if defined TFM_SNS_HEX if defined PYCMD %PYCMD% "%~dp0h5f4_win_images.py" hex2bin "%TFM_SNS_HEX%" "%TEMP%\h5f4_sns.bin"
if not defined TFM_S_NS_SIGNED if exist "%TEMP%\h5f4_sns.bin" if defined TFM_SNS_HEX set "TFM_S_NS_SIGNED=%TEMP%\h5f4_sns.bin"
if not defined TFM_S_NS_SIGNED if defined TFM_SNS_HEX set "TFM_S_NS_SIGNED=%TFM_SNS_HEX%"

if not defined TFM_BL2 (
    echo [FAIL] no bl2.bin or bl2.hex
    echo        Looked in cwd, this folder, build_s\api_ns\bin, build_s\bin, build_ns\bin
    echo        Copy bl2.bin tfm_s_signed.bin tfm_ns_signed.bin next to this bat
    echo        or run ./buildtfm.sh on this same tree so those folders exist.
    exit /b 1
)
if not defined TFM_S_SIGNED if not defined TFM_S_NS_SIGNED (
    echo [FAIL] no tfm_s_signed.bin/.hex and no tfm_s_ns_signed.bin/.hex
    exit /b 1
)
if not defined TFM_NS_SIGNED if not defined TFM_S_NS_SIGNED (
    echo [FAIL] no tfm_ns_signed.bin/.hex and no tfm_s_ns_signed.bin/.hex
    exit /b 1
)

echo [ok]   BL2        %TFM_BL2%
if defined TFM_S_SIGNED echo [ok]   S          %TFM_S_SIGNED%
if defined TFM_S_NS_SIGNED echo [ok]   S+NS       %TFM_S_NS_SIGNED%
if defined TFM_NS_SIGNED echo [ok]   NS         %TFM_NS_SIGNED%
exit /b 0
