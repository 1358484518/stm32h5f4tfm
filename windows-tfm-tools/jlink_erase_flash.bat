@echo off
rem One-click STM32H5F4 Flash erase via J-Link (WRPSG11/12/21/22, then -e all).
call "%~dp0erase_flash.bat" jlink %*
