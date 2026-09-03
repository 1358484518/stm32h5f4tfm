/*
 * SPDX-FileCopyrightText: Copyright The TrustedFirmware-M Contributors
 *
 * SPDX-License-Identifier: BSD-3-Clause
 *
 * Inflate the NS image toward ~1 MiB and touch the blob in 10 KB steps so a
 * board run proves the enlarged NS flash slot is executable end-to-end.
 */

#include <stdint.h>
#include <stddef.h>

#include "ns_flash_size_probe.h"
#include "test_log.h"

/*
 * Current NS image without this blob is roughly ~130–150 KB.  Target overall
 * firmware size near 1 MiB → keep ~896 KiB of flash-resident payload.
 */
#define NS_FLASH_PROBE_SIZE       (896u * 1024u)
#define NS_FLASH_PROBE_CHUNK      (10u * 1024u)

/*
 * Partially initialised const array still lives in .rodata and is programmed
 * into flash (remaining bytes are 0x00 in the image).
 */
static const uint8_t ns_flash_probe_blob[NS_FLASH_PROBE_SIZE]
    __attribute__((used, aligned(4))) = {
        [0] = 0xA5u,
        [1] = 0x5Au,
        [NS_FLASH_PROBE_SIZE - 1u] = 0xC3u,
    };

void ns_flash_size_probe(void)
{
    size_t offset;
    size_t i;
    uint32_t chunk_sum;
    uint32_t total_sum = 0u;
    size_t chunk_len;

    LOG_MSG("\r\n==== NS flash size probe ====\r\n");
    LOG_MSG("blob size=%u bytes (~%u KB)\r\n",
             (unsigned)NS_FLASH_PROBE_SIZE,
             (unsigned)(NS_FLASH_PROBE_SIZE / 1024u));

    for (offset = 0u; offset < NS_FLASH_PROBE_SIZE; offset += NS_FLASH_PROBE_CHUNK) {
        chunk_len = NS_FLASH_PROBE_CHUNK;
        if ((offset + chunk_len) > NS_FLASH_PROBE_SIZE) {
            chunk_len = NS_FLASH_PROBE_SIZE - offset;
        }

        chunk_sum = 0u;
        for (i = 0u; i < chunk_len; i++) {
            chunk_sum += ns_flash_probe_blob[offset + i];
        }
        total_sum += chunk_sum;

        LOG_MSG("NS flash read %u KB .. %u KB: sum=0x%08x\r\n",
                 (unsigned)(offset / 1024u),
                 (unsigned)((offset + chunk_len) / 1024u),
                 (unsigned)chunk_sum);
    }

    LOG_MSG("NS flash probe done, total_sum=0x%08x first=0x%02x last=0x%02x\r\n",
             (unsigned)total_sum,
             (unsigned)ns_flash_probe_blob[0],
             (unsigned)ns_flash_probe_blob[NS_FLASH_PROBE_SIZE - 1u]);
    LOG_MSG("==== NS flash size probe end ====\r\n\r\n");
}
