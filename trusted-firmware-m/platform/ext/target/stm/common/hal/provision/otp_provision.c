/**
  ******************************************************************************
  * @file    otp_provision.c
  * @author  MCD Application Team
  * @brief   File provisionning otp value
  *
  *
  ******************************************************************************
  * @attention
  *
  * <h2><center>&copy; Copyright (c) 2020-2021 STMicroelectronics.
  * All rights reserved.</center></h2>
  * <h2><center>&copy; Copyright (c) 2022 Cypress Semiconductor Corporation
  * (an Infineon company) or an affiliate of Cypress Semiconductor Corporation.
  * All rights reserved.</center></h2>
  *
  * This software component is licensed by ST under BSD 3-Clause license,
  * the "License"; You may not use this file except in compliance with the
  * License. You may obtain a copy of the License at:
  *                        opensource.org/licenses/BSD-3-Clause
  *
  ******************************************************************************
  */
#include "template/flash_otp_nv_counters_backend.h"
#include "tfm_plat_otp.h"
#include "tfm_attest_hal.h"
#include "psa/crypto.h"

#define INT2LE(A) (uint8_t)(A & 0xFF), (uint8_t )((A >> 8) & 0xFF),\
         (uint8_t )((A >> 16) & 0xFF), (uint8_t )((A >> 24) & 0xFF)


#define INT64NULL 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,  \
                  0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,  \
                  0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,  \
                  0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,  \
                  0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,  \
                  0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,  \
                  0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0,  \
                  0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0
#if defined(__ICCARM__)
__root
#endif
#if defined(__ICCARM__)
#pragma default_function_attributes = @ ".BL2_OTP_Const"
#else
__attribute__((section(".BL2_OTP_Const")))
#endif /* __ICCARM__ */
const struct flash_otp_nv_counters_region_t otp_stm_provision = {
    .init_value = OTP_NV_COUNTERS_INITIALIZED,
    /*
     * Device HUK / IAK / boot_seed / implementation_id come from
     * keys/otp_device_secrets.json via scripts/apply_stm_otp_device_secrets.py
     * (otp_device_secrets.inc). TFM_DUMMY_PROVISIONING must be OFF.
     */
#include "otp_device_secrets.inc"
    /* IAK len */
    .iak_len = { INT2LE(32) },
#ifdef SYMMETRIC_INITIAL_ATTESTATION
    /* IAK type */
    .iak_type= { INT2LE(PSA_ALG_HMAC(PSA_ALG_SHA_256))},
#else
    /* IAK type */
    .iak_type= { INT2LE(PSA_ECC_FAMILY_SECP_R1) },
#endif /* SYMMETRIC_INITIAL_ATTESTATION */
    /* IAK id */
    .iak_id = {'s','t','m','.','e','x','a','m','p',\
               'l','e','.','x','c','u','b','e','!'},
#include "otp_device_seed_impl.inc"
    .lcs= {INT2LE(PLAT_OTP_LCS_SECURED)},

    /* certification reference */
    .cert_ref = { '0','6','0','4','5','6','5','2','7',
                  '2','8','2','9','1','0','0','1','0'},
    /* verification_service_url */
    .verification_service_url = "www.trustedfirmware.org",
    /* attestation_profile_definition */
    .profile_definition ="PSA_IOT_PROFILE_1",
    /*
     * BL2 ROTPK hashes for the flash-emulated OTP region (programmed via bl2.hex).
     * Auto-synced from MCUboot signing keys by scripts/sync_stm_otp_rotpk.py
     * (called from ./buildtfm.sh). Do not hand-edit otp_rotpk_hashes.inc.
     */
#include "otp_rotpk_hashes.inc"
    /* Entropy seed */
    .entropy_seed ={
        0x12, 0x13, 0x23, 0x34, 0x0a, 0x05, 0x89, 0x78,
        0xa3, 0x66, 0x8c, 0x0d, 0x97, 0x55, 0x53, 0xca,
        0xb5, 0x76, 0x18, 0x62, 0x29, 0xc6, 0xb6, 0x79,
        0x75, 0xc8, 0x5a, 0x8d, 0x9e, 0x11, 0x8f, 0x85,
        0xde, 0xc4, 0x5f, 0x66, 0x21, 0x52, 0xf9, 0x39,
        0xd9, 0x77, 0x93, 0x28, 0xb0, 0x5e, 0x02, 0xfa,
        0x58, 0xb4, 0x16, 0xc8, 0x0f, 0x38, 0x91, 0xbb,
        0x28, 0x17, 0xcd, 0x8a, 0xc9, 0x53, 0x72, 0x66,
    },
#ifdef PLATFORM_DEFAULT_NV_COUNTERS
    .flash_nv_counters = { 0x0, 0x0, 0x0 },
#endif
    .swap_count =  1
};
