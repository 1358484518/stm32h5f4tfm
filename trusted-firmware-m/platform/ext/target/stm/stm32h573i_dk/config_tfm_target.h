/*
 * Copyright (c) 2022-2024, Arm Limited. All rights reserved.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 *
 */

#ifndef __CONFIG_TFM_TARGET_H__
#define __CONFIG_TFM_TARGET_H__

/* Use stored NV seed to provide entropy */
#undef CRYPTO_NV_SEED
#define CRYPTO_NV_SEED                         0

/* Use external RNG to provide entropy */
#define CRYPTO_EXT_RNG                         1

/* ITS encryption uses mbedtls_gcm in-partition; give it enough stack. */
#undef ITS_STACK_SIZE
#define ITS_STACK_SIZE                         0x1000

/* ../ns_app/mbedtls-4.1.1/library/ssl_tls13_generic.c:1621 0x2005a788: psa_export_public_key() returned -141  */
#define CRYPTO_IOVEC_BUFFER_SIZE  20480

#endif /* __CONFIG_TFM_TARGET_H__ */
