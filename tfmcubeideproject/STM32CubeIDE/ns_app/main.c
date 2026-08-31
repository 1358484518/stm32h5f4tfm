/*
 * Bare-metal NS smoke test for STM32H5F4 + TF-M SPE.
 *
 * Bring-up follows tf-m-tests/app_broker/main_ns.c (without RTX):
 *   tfm_ns_platform_init() -> stdio_init()
 *   tfm_ns_cp_init()
 *   tfm_ns_interface_init()
 *
 * Logging matches tf-m-tests: LOG_MSG -> tfm_log_printf -> stdio_output_string.
 * Do not use newlib printf (official NS tests never do).
 *
 * All other C files come from TF-M or tf-m-tests (or the SPE api_ns export).
 *
 * Requires the matching flashed tfm_s.bin (s_veneers.o addresses must match).
 * USART1 PA9/PA10: 115200 8N1.
 *
 * If SPE was built with TEST_S=ON, colored "PASSED" / "*** End of Secure
 * test suites ***" prints first. This app then prints NS-SMOKE.
 */

#include <string.h>
#include <stdint.h>

#include "Driver_USART.h"
#include "tfm_plat_ns.h"
#include "tfm_ns_interface.h"
#include "os_wrapper/common.h"
#include "test_log.h"

#include "psa/crypto.h"
#include "psa/error.h"
#include "psa/internal_trusted_storage.h"
#include "psa/update.h"

#include "mbedtls/md.h"
#include "mbedtls/version.h"

static int g_fail;

/* tfm_log_printf has no %02x; print two lowercase hex digits per byte. */
static void log_hex(const uint8_t *buf, size_t len)
{
    size_t i;

    for (i = 0; i < len; i++) {
        LOG_MSG("%x%x", (unsigned)((buf[i] >> 4) & 0xfu),
                (unsigned)(buf[i] & 0xfu));
    }
}

static void check(const char *what, psa_status_t status)
{
    if (status == PSA_SUCCESS) {
        LOG_MSG("  [PASS] %s\r\n", what);
    } else {
        LOG_MSG("  [FAIL] %s status=%d\r\n", what, (int)status);
        g_fail++;
    }
}

static void test_crypto(void)
{
    static const uint8_t msg[] = "abc";
    /* FIPS 180-2 SHA-256("abc") */
    static const uint8_t expect[32] = {
        0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea,
        0x41, 0x41, 0x40, 0xde, 0x5d, 0xae, 0x22, 0x23,
        0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c,
        0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00, 0x15, 0xad
    };
    uint8_t hash[32];
    size_t hash_len = 0;
    psa_status_t status;

    LOG_MSG("PSA Crypto\r\n");
    status = psa_crypto_init();
    check("psa_crypto_init", status);
    if (status != PSA_SUCCESS) {
        return;
    }

    status = psa_hash_compute(PSA_ALG_SHA_256, msg, sizeof(msg) - 1u,
                              hash, sizeof(hash), &hash_len);
    check("psa_hash_compute(SHA-256)", status);
    if (status == PSA_SUCCESS) {
        LOG_MSG("  hash=");
        log_hex(hash, hash_len);
        LOG_MSG("\r\n");
        if ((hash_len != sizeof(expect)) ||
            (memcmp(hash, expect, sizeof(expect)) != 0)) {
            LOG_MSG("  [FAIL] SHA-256 known-answer mismatch\r\n");
            g_fail++;
        } else {
            LOG_MSG("  [PASS] SHA-256 known-answer\r\n");
        }
    }
}

static void check_bytes(const char *what, const uint8_t *got, const uint8_t *exp,
                        size_t len)
{
    if (memcmp(got, exp, len) == 0) {
        LOG_MSG("  [PASS] %s\r\n", what);
    } else {
        LOG_MSG("  [FAIL] %s mismatch got=", what);
        log_hex(got, len);
        LOG_MSG("\r\n");
        g_fail++;
    }
}

static psa_status_t import_aes_key(psa_key_id_t *key_id, const uint8_t *key,
                                  size_t key_len, psa_algorithm_t alg,
                                  psa_key_usage_t usage)
{
    psa_key_attributes_t attr = PSA_KEY_ATTRIBUTES_INIT;
    psa_status_t status;

    psa_set_key_usage_flags(&attr, usage);
    psa_set_key_algorithm(&attr, alg);
    psa_set_key_type(&attr, PSA_KEY_TYPE_AES);
    psa_set_key_bits(&attr, key_len * 8u);

    status = psa_import_key(&attr, key, key_len, key_id);
    psa_reset_key_attributes(&attr);
    return status;
}

/*
 * mbedtls 4.1.1 NS build: no software AES (aes.c not compiled).
 * Cipher/AEAD go through the PSA client (s_veneers.o) into the SPE.
 * Hash helpers in md.c also call PSA.
 */
static void test_mbedtls_aes_cbc(void)
{
    /* NIST SP 800-38A F.2.1 CBC-AES128, one block. */
    static const uint8_t key[16] = {
        0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6,
        0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c
    };
    static const uint8_t iv[16] = {
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
        0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f
    };
    static const uint8_t pt[16] = {
        0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96,
        0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a
    };
    static const uint8_t ct_expect[16] = {
        0x76, 0x49, 0xab, 0xac, 0x81, 0x19, 0xb2, 0x46,
        0xce, 0xe9, 0x8e, 0x9b, 0x12, 0xe9, 0x19, 0x7d
    };
    uint8_t ct[16];
    uint8_t pt_out[16];
    size_t olen = 0;
    size_t flen = 0;
    psa_key_id_t key_id = 0;
    psa_cipher_operation_t op = PSA_CIPHER_OPERATION_INIT;
    psa_status_t status;

    LOG_MSG("mbedtls AES-128-CBC (PSA -> SPE)\r\n");

    status = import_aes_key(&key_id, key, sizeof(key), PSA_ALG_CBC_NO_PADDING,
                            PSA_KEY_USAGE_ENCRYPT | PSA_KEY_USAGE_DECRYPT);
    check("psa_import_key(AES-CBC)", status);
    if (status != PSA_SUCCESS) {
        return;
    }

    status = psa_cipher_encrypt_setup(&op, key_id, PSA_ALG_CBC_NO_PADDING);
    check("psa_cipher_encrypt_setup", status);
    status = psa_cipher_set_iv(&op, iv, sizeof(iv));
    check("psa_cipher_set_iv(enc)", status);
    memset(ct, 0, sizeof(ct));
    olen = 0;
    status = psa_cipher_update(&op, pt, sizeof(pt), ct, sizeof(ct), &olen);
    check("psa_cipher_update(enc)", status);
    flen = 0;
    status = psa_cipher_finish(&op, ct + olen, sizeof(ct) - olen, &flen);
    check("psa_cipher_finish(enc)", status);
    (void)psa_cipher_abort(&op);
    if (olen + flen == sizeof(ct_expect)) {
        check_bytes("AES-CBC ciphertext", ct, ct_expect, sizeof(ct_expect));
        LOG_MSG("  ct=");
        log_hex(ct, sizeof(ct));
        LOG_MSG("\r\n");
    } else {
        LOG_MSG("  [FAIL] AES-CBC enc length %u\r\n",
                (unsigned)(olen + flen));
        g_fail++;
    }

    memset(&op, 0, sizeof(op));
    status = psa_cipher_decrypt_setup(&op, key_id, PSA_ALG_CBC_NO_PADDING);
    check("psa_cipher_decrypt_setup", status);
    status = psa_cipher_set_iv(&op, iv, sizeof(iv));
    check("psa_cipher_set_iv(dec)", status);
    memset(pt_out, 0, sizeof(pt_out));
    olen = 0;
    status = psa_cipher_update(&op, ct, sizeof(ct), pt_out, sizeof(pt_out),
                               &olen);
    check("psa_cipher_update(dec)", status);
    flen = 0;
    status = psa_cipher_finish(&op, pt_out + olen, sizeof(pt_out) - olen,
                               &flen);
    check("psa_cipher_finish(dec)", status);
    (void)psa_cipher_abort(&op);
    if (olen + flen == sizeof(pt)) {
        check_bytes("AES-CBC decrypt roundtrip", pt_out, pt, sizeof(pt));
    } else {
        LOG_MSG("  [FAIL] AES-CBC dec length %u\r\n",
                (unsigned)(olen + flen));
        g_fail++;
    }

    (void)psa_destroy_key(key_id);
}

static void test_mbedtls_aes_gcm(void)
{
    /* NIST CAVS AES-GCM 128, 12-byte IV, 16-byte PT, empty AAD. */
    static const uint8_t key[16] = { 0 };
    static const uint8_t iv[12] = { 0 };
    static const uint8_t pt[16] = { 0 };
    static const uint8_t ct_expect[16] = {
        0x03, 0x88, 0xda, 0xce, 0x60, 0xb6, 0xa3, 0x92,
        0xf3, 0x28, 0xc2, 0xb9, 0x71, 0xb2, 0xfe, 0x78
    };
    static const uint8_t tag_expect[16] = {
        0xab, 0x6e, 0x47, 0xd4, 0x2c, 0xec, 0x13, 0xbd,
        0xf5, 0x3a, 0x67, 0xb2, 0x12, 0x57, 0xbd, 0xdf
    };
    uint8_t out[32];
    uint8_t pt_out[16];
    size_t olen = 0;
    psa_key_id_t key_id = 0;
    psa_status_t status;

    LOG_MSG("mbedtls AES-128-GCM (PSA -> SPE)\r\n");

    status = import_aes_key(&key_id, key, sizeof(key), PSA_ALG_GCM,
                            PSA_KEY_USAGE_ENCRYPT | PSA_KEY_USAGE_DECRYPT);
    check("psa_import_key(AES-GCM)", status);
    if (status != PSA_SUCCESS) {
        return;
    }

    memset(out, 0, sizeof(out));
    olen = 0;
    status = psa_aead_encrypt(key_id, PSA_ALG_GCM, iv, sizeof(iv),
                              NULL, 0, pt, sizeof(pt),
                              out, sizeof(out), &olen);
    check("psa_aead_encrypt", status);
    if ((status == PSA_SUCCESS) && (olen == 32u)) {
        check_bytes("AES-GCM ciphertext", out, ct_expect, sizeof(ct_expect));
        check_bytes("AES-GCM tag", out + 16, tag_expect, sizeof(tag_expect));
        LOG_MSG("  ct+tag=");
        log_hex(out, olen);
        LOG_MSG("\r\n");
    } else if (status == PSA_SUCCESS) {
        LOG_MSG("  [FAIL] AES-GCM enc length %u\r\n", (unsigned)olen);
        g_fail++;
    }

    memset(pt_out, 0, sizeof(pt_out));
    olen = 0;
    status = psa_aead_decrypt(key_id, PSA_ALG_GCM, iv, sizeof(iv),
                              NULL, 0, out, 32u,
                              pt_out, sizeof(pt_out), &olen);
    check("psa_aead_decrypt", status);
    if ((status == PSA_SUCCESS) && (olen == sizeof(pt))) {
        check_bytes("AES-GCM decrypt roundtrip", pt_out, pt, sizeof(pt));
    } else if (status == PSA_SUCCESS) {
        LOG_MSG("  [FAIL] AES-GCM dec length %u\r\n", (unsigned)olen);
        g_fail++;
    }

    (void)psa_destroy_key(key_id);
}

static void test_mbedtls_md_sha256(void)
{
    static const uint8_t msg[] = "abc";
    static const uint8_t expect[32] = {
        0xba, 0x78, 0x16, 0xbf, 0x8f, 0x01, 0xcf, 0xea,
        0x41, 0x41, 0x40, 0xde, 0x5d, 0xae, 0x22, 0x23,
        0xb0, 0x03, 0x61, 0xa3, 0x96, 0x17, 0x7a, 0x9c,
        0xb4, 0x10, 0xff, 0x61, 0xf2, 0x00, 0x15, 0xad
    };
    uint8_t hash[32];
    const mbedtls_md_info_t *info;
    int ret;

    LOG_MSG("mbedtls_md SHA-256\r\n");
    info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
    if (info == NULL) {
        LOG_MSG("  [FAIL] mbedtls_md_info_from_type(SHA-256)\r\n");
        g_fail++;
        return;
    }

    memset(hash, 0, sizeof(hash));
    ret = mbedtls_md(info, msg, sizeof(msg) - 1u, hash);
    if (ret == 0) {
        LOG_MSG("  [PASS] mbedtls_md(SHA-256)\r\n");
        check_bytes("mbedtls_md known-answer", hash, expect, sizeof(expect));
    } else {
        LOG_MSG("  [FAIL] mbedtls_md ret=%d\r\n", ret);
        g_fail++;
    }
}

static void test_mbedtls_crypto(void)
{
    LOG_MSG("mbedtls %s\r\n", mbedtls_version_get_string());
    test_mbedtls_md_sha256();
    test_mbedtls_aes_cbc();
    test_mbedtls_aes_gcm();
}

static void test_its(void)
{
    const psa_storage_uid_t uid = 0x0000000000001001ULL;
    static const uint8_t payload[] = "ns-its";
    uint8_t readback[16];
    size_t read_len = 0;
    psa_status_t status;

    LOG_MSG("PSA ITS\r\n");
    (void)psa_its_remove(uid);

    status = psa_its_set(uid, sizeof(payload), payload, PSA_STORAGE_FLAG_NONE);
    check("psa_its_set", status);

    memset(readback, 0, sizeof(readback));
    status = psa_its_get(uid, 0, sizeof(readback), readback, &read_len);
    check("psa_its_get", status);
    if ((status == PSA_SUCCESS) &&
        ((read_len != sizeof(payload)) ||
         (memcmp(readback, payload, sizeof(payload)) != 0))) {
        LOG_MSG("  [FAIL] ITS payload mismatch\r\n");
        g_fail++;
    }

    status = psa_its_remove(uid);
    check("psa_its_remove", status);
}

static void test_fwu_query(void)
{
    psa_fwu_component_info_t info;
    psa_status_t status;

    LOG_MSG("PSA FWU query\r\n");

    memset(&info, 0, sizeof(info));
    status = psa_fwu_query(FWU_COMPONENT_ID_SECURE, &info);
    check("psa_fwu_query(S)", status);
    if (status == PSA_SUCCESS) {
        LOG_MSG("  S  state=%u max_size=%u\r\n",
                (unsigned)info.state, (unsigned)info.max_size);
    }

    memset(&info, 0, sizeof(info));
    status = psa_fwu_query(FWU_COMPONENT_ID_NONSECURE, &info);
    check("psa_fwu_query(NS)", status);
    if (status == PSA_SUCCESS) {
        LOG_MSG("  NS state=%u max_size=%u\r\n",
                (unsigned)info.state, (unsigned)info.max_size);
    }
}

int main(void)
{
    if (tfm_ns_platform_init() != ARM_DRIVER_OK) {
        for (;;) {
        }
    }

    if (tfm_ns_cp_init() != ARM_DRIVER_OK) {
        for (;;) {
        }
    }

    LOG_MSG("\r\nNS-SMOKE\r\n");
    LOG_MSG("Non-Secure system starting...\r\n");

    if (tfm_ns_interface_init() != OS_WRAPPER_SUCCESS) {
        LOG_MSG("tfm_ns_interface_init failed\r\n");
        for (;;) {
        }
    }
    LOG_MSG("tfm_ns_interface_init ok\r\n");

    test_crypto();
    test_mbedtls_crypto();
    test_its();
    test_fwu_query();

    if (g_fail == 0) {
        LOG_MSG("ALL PASSED\r\n");
    } else {
        LOG_MSG("FAILED count=%d\r\n", g_fail);
    }

    for (;;) {
    }
}
