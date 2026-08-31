#!/usr/bin/env bash
#******************************************************************************
#  * @attention
#  *
#  * <h2><center>&copy; Copyright (c) 2019 STMicroelectronics.
#  * All rights reserved.</center></h2>
#  *
#  * This software component is licensed by ST under BSD 3-Clause license,
#  * the "License"; You may not use this file except in compliance with the
#  * License. You may obtain a copy of the License at:
#  *                        opensource.org/licenses/BSD-3-Clause
#  *
#  ******************************************************************************
# STM32H5F4: WRP names are WRPSG11/12/21/22 (not H573 WRPSGn1).
# HDP1 can be enlarged but not shrunk by -ob once STRT<=END. Old BL2 sets
# HDP1=[0, 0x13] over the whole BL2 region. Mass-erase first so the old
# image cannot re-apply HDP, then try HDP1_STRT=1 HDP1_END=0.
echo "regression script started"
sn_option=""
if [ $# -eq 1 ]; then
sn_option="sn=$1"
fi
PATH="/C/Program Files/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/":$PATH
stm32programmercli="STM32_Programmer_CLI"
connect="-c port=SWD ap=1 "$sn_option" mode=UR"
connect_no_reset="-c port=SWD ap=1 "$sn_option" mode=HotPlug"
echo "Regression platform STM32H5F4"
product_state="-ob PRODUCT_STATE=0xED  TZEN=0xB4"
# H5F4: 256 sectors per 2 MB bank (last sector index 255)
remove_bank1_protect="-ob SECWM1_STRT=255 SECWM1_END=0 WRPSG11=0xffffffff WRPSG12=0xffffffff"
remove_bank2_protect="-ob SECWM2_STRT=255 SECWM2_END=0 WRPSG21=0xffffffff WRPSG22=0xffffffff"
erase_all="-e all"
remove_hdp_protection="-ob HDP1_STRT=1 HDP1_END=0 HDP2_STRT=1 HDP2_END=0"
default_ob1="-ob SECBOOTADD="0xC0100" HDP1_STRT=1 HDP1_END=0 HDP2_STRT=1 HDP2_END=0 SWAP_BANK=0 SRAM2_RST=0 SRAM2_ECC=0"
default_ob2="-ob SECWM2_STRT=0 SECWM2_END=255 SECWM1_STRT=0 SECWM1_END=255"


echo "Regression to PRODUCT_STATE 0xED and  tzen=1"
$stm32programmercli $connect $product_state
echo "Remove bank1 WRP/watermark and erase all (kills old BL2 before HDP retry)"
$stm32programmercli $connect $remove_bank1_protect $erase_all
if [ $? -ne 0 ]; then
  echo "ERROR: mass erase of bank1 path failed"
  exit 1
fi
echo "Remove bank2 WRP/watermark and erase all"
$stm32programmercli $connect $remove_bank2_protect $erase_all
echo "Remove hdp protection (only sticks after old BL2 is gone; may still stay [0, 0x13])"
$stm32programmercli $connect $remove_hdp_protection
echo "Set default OB 1 (dual bank, swap bank, sram2 reset, secure entry point, bank 1 full secure)"
$stm32programmercli $connect_no_reset $default_ob1
echo "Set default OB 2 (bank 2 full secure)"
$stm32programmercli $connect_no_reset $default_ob2
echo "Option bytes after regression:"
$stm32programmercli $connect_no_reset -ob displ | grep -E "WRP|HDP|PRODUCT|SECWM" || true
echo "regression script Done"
