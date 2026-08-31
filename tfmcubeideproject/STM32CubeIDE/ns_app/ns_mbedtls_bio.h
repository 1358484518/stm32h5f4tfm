/*
 * mbedtls BIO (mbedtls_ssl_set_bio) for the NS TLS 1.3 client.
 *
 * Default callbacks are a non-blocking stub: send records the ClientHello,
 * recv returns WANT_READ (no peer). Replace ns_mbedtls_bio_send/recv with
 * your TCP (lwIP / sockets / Ethernet) for a real handshake.
 */
#ifndef NS_MBEDTLS_BIO_H
#define NS_MBEDTLS_BIO_H

#include "mbedtls/ssl.h"

#include <stddef.h>
#include <stdint.h>

#define NS_MBEDTLS_BIO_TX_MAX  4096u

struct ns_mbedtls_bio {
    uint8_t tx[NS_MBEDTLS_BIO_TX_MAX];
    size_t tx_len;
};

void ns_mbedtls_bio_init(struct ns_mbedtls_bio *bio);

int ns_mbedtls_bio_send(void *ctx, const unsigned char *buf, size_t len);
int ns_mbedtls_bio_recv(void *ctx, unsigned char *buf, size_t len);

#endif /* NS_MBEDTLS_BIO_H */
