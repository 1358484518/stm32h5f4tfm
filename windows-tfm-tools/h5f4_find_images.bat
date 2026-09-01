@echo off
rem Find TF-M images. Prefer .bin; if none, convert matching .hex to .bin.
rem 1) current directory and this folder
rem 2) TF-M build output if still missing
rem Do not use CALL :label. Caller sees TFM_BL2 / TFM_S_SIGNED / TFM_NS_SIGNED
rem / TFM_S_NS_SIGNED.

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
set "H5F4_BIN_NS=%~dp0..\trusted-firmware-m\build_ns\bin"

echo [info] find .bin in cwd / this folder, else .hex -^> .bin, else TF-M build output

for %%D in ("%CD%" "%~dp0.") do (
    if not defined TFM_BL2 if exist "%%~fD\bl2.bin" set "TFM_BL2=%%~fD\bl2.bin"
    if not defined TFM_S_SIGNED if exist "%%~fD\tfm_s_signed.bin" set "TFM_S_SIGNED=%%~fD\tfm_s_signed.bin"
    if not defined TFM_NS_SIGNED if exist "%%~fD\tfm_ns_signed.bin" set "TFM_NS_SIGNED=%%~fD\tfm_ns_signed.bin"
    if not defined TFM_S_NS_SIGNED if exist "%%~fD\tfm_s_ns_signed.bin" set "TFM_S_NS_SIGNED=%%~fD\tfm_s_ns_signed.bin"
)
for %%D in ("%CD%" "%~dp0.") do (
    if not defined TFM_BL2 if not defined TFM_BL2_HEX if exist "%%~fD\bl2.hex" set "TFM_BL2_HEX=%%~fD\bl2.hex"
    if not defined TFM_S_SIGNED if not defined TFM_S_HEX if exist "%%~fD\tfm_s_signed.hex" set "TFM_S_HEX=%%~fD\tfm_s_signed.hex"
    if not defined TFM_NS_SIGNED if not defined TFM_NS_HEX if exist "%%~fD\tfm_ns_signed.hex" set "TFM_NS_HEX=%%~fD\tfm_ns_signed.hex"
    if not defined TFM_S_NS_SIGNED if not defined TFM_SNS_HEX if exist "%%~fD\tfm_s_ns_signed.hex" set "TFM_SNS_HEX=%%~fD\tfm_s_ns_signed.hex"
)
for %%D in ("%H5F4_BIN_S%" "%H5F4_BIN_NS%") do (
    if not defined TFM_BL2 if not defined TFM_BL2_HEX if exist "%%~fD\bl2.bin" set "TFM_BL2=%%~fD\bl2.bin"
    if not defined TFM_S_SIGNED if not defined TFM_S_HEX if exist "%%~fD\tfm_s_signed.bin" set "TFM_S_SIGNED=%%~fD\tfm_s_signed.bin"
    if not defined TFM_NS_SIGNED if not defined TFM_NS_HEX if exist "%%~fD\tfm_ns_signed.bin" set "TFM_NS_SIGNED=%%~fD\tfm_ns_signed.bin"
    if not defined TFM_S_NS_SIGNED if not defined TFM_SNS_HEX if exist "%%~fD\tfm_s_ns_signed.bin" set "TFM_S_NS_SIGNED=%%~fD\tfm_s_ns_signed.bin"
)
for %%D in ("%H5F4_BIN_S%" "%H5F4_BIN_NS%") do (
    if not defined TFM_BL2 if not defined TFM_BL2_HEX if exist "%%~fD\bl2.hex" set "TFM_BL2_HEX=%%~fD\bl2.hex"
    if not defined TFM_S_SIGNED if not defined TFM_S_HEX if exist "%%~fD\tfm_s_signed.hex" set "TFM_S_HEX=%%~fD\tfm_s_signed.hex"
    if not defined TFM_NS_SIGNED if not defined TFM_NS_HEX if exist "%%~fD\tfm_ns_signed.hex" set "TFM_NS_HEX=%%~fD\tfm_ns_signed.hex"
    if not defined TFM_S_NS_SIGNED if not defined TFM_SNS_HEX if exist "%%~fD\tfm_s_ns_signed.hex" set "TFM_SNS_HEX=%%~fD\tfm_s_ns_signed.hex"
)

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
    echo        Put files in the current directory or next to this bat:
    echo          bl2.bin  tfm_s_signed.bin  tfm_ns_signed.bin
    echo        or keep trusted-firmware-m\build_s\api_ns\bin from ./buildtfm.sh
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
