/*
 * SPDX-FileCopyrightText: Copyright The TrustedFirmware-M Contributors
 *
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Debug helper: walk a large flash-resident blob and print every 10 KB.
 * Added for STM32H573 debug NS flash-map validation; does not replace tests.
 */

#ifndef NS_FLASH_SIZE_PROBE_H
#define NS_FLASH_SIZE_PROBE_H

#ifdef __cplusplus
extern "C" {
#endif

void ns_flash_size_probe(void);

#ifdef __cplusplus
}
#endif

#endif /* NS_FLASH_SIZE_PROBE_H */
