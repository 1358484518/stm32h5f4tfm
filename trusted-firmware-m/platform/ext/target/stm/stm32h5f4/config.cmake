#-------------------------------------------------------------------------------
# SPDX-FileCopyrightText: Copyright The TrustedFirmware-M Contributors
# Copyright (c) 2021 STMicroelectronics. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
#-------------------------------------------------------------------------------

################################## BL2 #################################################
set(MCUBOOT_IMAGE_NUMBER                   2           CACHE STRING    "Whether to combine S and NS into either 1 image, or sign each seperately")
set(BL2_HEADER_SIZE                        0x400       CACHE STRING    "Header size")
set(BL2_TRAILER_SIZE                       0x3000      CACHE STRING    "Trailer size" FORCE)
set(MCUBOOT_ALIGN_VAL                      16          CACHE STRING    "Align option to build image with imgtool")
set(MCUBOOT_UPGRADE_STRATEGY        "SWAP_USING_SCRATCH"      CACHE STRING    "Upgrade strategy for images")
set(MCUBOOT_USE_PSA_CRYPTO                 ON          CACHE BOOL      "Enable the cryptographic abstraction layer to use PSA Crypto APIs")
set(TFM_PARTITION_PLATFORM                 ON          CACHE BOOL      "Enable platform partition")
set(MCUBOOT_DATA_SHARING                   ON          CACHE BOOL      "Enable Data Sharing")
set(MCUBOOT_BOOTSTRAP                      ON          CACHE BOOL      "Allow initial state with images in secondary slots(empty primary slots)")
set(MCUBOOT_ENC_IMAGES                     OFF          CACHE BOOL      "Enable encrypted image upgrade support")
set(MCUBOOT_ENCRYPT_RSA                    OFF          CACHE BOOL      "Use RSA for encrypted image upgrade support")
# This branch (stm32h5f4-p256): MCUboot image signatures are ECDSA P-256
# (not the TF-M default RSA-3072). Changing this requires a clean rebuild
# of BL2/SPE and matching sign_kit keys (see readme.md).
set(MCUBOOT_SIGNATURE_TYPE                 "EC-P256"    CACHE STRING    "Algorithm to use for signature validation [RSA-2048, RSA-3072, EC-P256, EC-P384]")
################################## Dependencies ########################################
set(TFM_PARTITION_INTERNAL_TRUSTED_STORAGE ON          CACHE BOOL      "Enable Internal Trusted Storage partition")
set(TFM_PARTITION_CRYPTO                   ON          CACHE BOOL      "Enable Crypto partition")
set(CRYPTO_HW_ACCELERATOR                  ON          CACHE BOOL      "Whether to enable the crypto hardware accelerator on supported platforms")
set(TF_PSA_CRYPTO_BUILD_TYPE               minsizerel  CACHE STRING    "Build type of TF-PSA-Crypto library")
set(MCUBOOT_FIH_PROFILE                    LOW         CACHE STRING    "Fault injection hardening profile [OFF, LOW, MEDIUM, HIGH]")
################################## LOG LEVEL ###########################################
set(TFM_SPM_LOG_LEVEL             LOG_LEVEL_INFO       CACHE STRING    "Set default SPM log level as INFO level")
set(TFM_PARTITION_LOG_LEVEL       LOG_LEVEL_INFO       CACHE STRING    "Set default Secure Partition log level as INFO level")
set(MCUBOOT_HW_ROLLBACK_PROT            ON          CACHE BOOL      "Enable security counter validation against non-volatile HW counters")
################################## Platform-specific configurations ####################################
set(CONFIG_TFM_USE_TRUSTZONE               ON           CACHE BOOL      "Use TrustZone")
set(TFM_PARTITION_PROTECTED_STORAGE        ON           CACHE BOOL      "Disable Protected Storage partition")
set(TFM_PARTITION_INITIAL_ATTESTATION      ON           CACHE BOOL      "Disable Initial Attestation partition")
set(PLATFORM_HAS_FIRMWARE_UPDATE_SUPPORT   ON           CACHE BOOL      "Wheter the platform has firmware update support")
################################## Production device secrets (on-chip OTP) ############################
# HUK/IAK/boot_seed/implementation_id are read from STM32H5 Flash OTP @ 0x08FFF000
# (factory-programmed). ROTPK hashes stay in flash-emulated OTP and are synced from keys/.
# Do NOT enable TFM_DUMMY_PROVISIONING on this branch.
set(STM_PROD_CHIP_OTP_SECRETS              ON           CACHE BOOL      "Use on-chip Flash OTP for HUK/IAK device secrets")
set(STM_PROD_DHUK_WRAP_HUK                 ON           CACHE BOOL      "Protect OTP HUK with SAES DHUK (AES-CBC); unwrap at runtime")
set(TFM_DUMMY_PROVISIONING                 OFF          CACHE BOOL      "Provision with dummy values. NOT for production")
set(PLATFORM_DEFAULT_OTP                   OFF          CACHE BOOL      "Use stock otp_flash.c; replaced by stm_otp_flash_prod.c")
set(PLATFORM_DEFAULT_OTP_WRITEABLE         ON           CACHE BOOL      "Allow writes to flash-emulated OTP (ROTPK/NV); chip OTP is R/O at runtime")
################################## FIRMWARE_UPDATE #############################################################
set(TFM_PARTITION_FIRMWARE_UPDATE          ON           CACHE BOOL      "Enable firmware update partition")
set(TFM_FWU_BOOTLOADER_LIB                 "mcuboot"    CACHE STRING    "Bootloader configure file for Firmware Update partition")
set(TFM_CONFIG_FWU_MAX_WRITE_SIZE          1024         CACHE STRING    "The maximum permitted size for block in psa_fwu_write, in bytes.")
set(TFM_CONFIG_FWU_MAX_MANIFEST_SIZE       0            CACHE STRING    "The maximum permitted size for manifest in psa_fwu_start(), in bytes.")
set(FWU_DEVICE_CONFIG_FILE                 ""           CACHE STRING    "The device configuration file for Firmware Update partition")
set(DMCUBOOT_UPGRADE_STRATEGY              SWAP_USING_MOVE)
set(DEFAULT_MCUBOOT_FLASH_MAP             ON            CACHE BOOL     "Whether to use the default flash map defined by TF-M project")
