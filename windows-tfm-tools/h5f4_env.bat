@echo off
rem STM32H5F4 flash map, option-byte names, and CubeProgrammer PATH.
rem Do not use H573 values: WRPSGn1, SECWM ...=127, NS slot 0x0C088000.
set "H5F4_REV=h5f4-20260831-cli"
set "H5F4_ADDR_BL2_S=0x0C00E000"
set "H5F4_ADDR_S_S=0x0C038000"
set "H5F4_ADDR_NS_S=0x0C090000"
set "H5F4_ADDR_BL2_NS=0x0800E000"
set "H5F4_ADDR_S_NS=0x08038000"
set "H5F4_ADDR_NS_NS=0x08090000"
set "H5F4_SECWM_OPEN=SECWM1_STRT=255 SECWM1_END=0 SECWM2_STRT=255 SECWM2_END=0"
set "H5F4_SECWM_FULL=SECWM1_STRT=0 SECWM1_END=255 SECWM2_STRT=0 SECWM2_END=255"
set "H5F4_WRP=WRPSG11=0xffffffff WRPSG12=0xffffffff WRPSG21=0xffffffff WRPSG22=0xffffffff"
set "H5F4_HDP_OFF=HDP1_STRT=1 HDP1_END=0 HDP2_STRT=1 HDP2_END=0"
set "H5F4_OB1=SECBOOTADD=0xC0100 HDP1_STRT=1 HDP1_END=0 HDP2_STRT=1 HDP2_END=0 SWAP_BANK=0 SRAM2_RST=0 SRAM2_ECC=0"
set "H5F4_BOOT_UBE=BOOT_UBE=0xB4"
set "H5F4_PRODUCT_STATE=PRODUCT_STATE=0xED TZEN=0xB4"

if defined H5F4_PATH_DONE goto :h5f4_env_done
call :h5f4_prepend_cli "D:\ST\STM32CubeProgrammer\bin"
call :h5f4_prepend_cli "%ProgramFiles%\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin"
call :h5f4_prepend_cli "%ProgramFiles(x86)%\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin"
call :h5f4_prepend_cli "C:\Program Files\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin"
call :h5f4_prepend_cli "C:\ST\STM32CubeProgrammer\bin"
call :h5f4_prepend_cli "%ProgramFiles%\STMicroelectronics\STM32CubeProgrammer\bin"
call :h5f4_prepend_cli "%LOCALAPPDATA%\Programs\STM32CubeProgrammer\bin"
for /d %%D in ("%ProgramFiles%\SEGGER\JLink*") do (
    if exist "%%~D\JLinkARM.dll" set "PATH=%%~D;%PATH%"
)
set "H5F4_PATH_DONE=1"
goto :h5f4_env_done

:h5f4_prepend_cli
if exist "%~1\STM32_Programmer_CLI.exe" (
    echo [info] CubeProgrammer bin = %~1
    set "PATH=%~1;%PATH%"
)
goto :eof

:h5f4_env_done
