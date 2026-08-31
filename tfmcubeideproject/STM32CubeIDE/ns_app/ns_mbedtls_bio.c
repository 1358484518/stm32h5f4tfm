#include "ns_mbedtls_bio.h"

#include <string.h>

void ns_mbedtls_bio_init(struct ns_mbedtls_bio *bio)
{
    if (bio == NULL) {
        return;
    }
    memset(bio, 0, sizeof(*bio));
}

int ns_mbedtls_bio_send(void *ctx, const unsigned char *buf, size_t len)
{
    struct ns_mbedtls_bio *bio = ctx;
    size_t copy;

    if ((bio == NULL) || (buf == NULL) || (len == 0u)) {
        return MBEDTLS_ERR_SSL_BAD_INPUT_DATA;
    }

    copy = len;
    if (copy > (NS_MBEDTLS_BIO_TX_MAX - bio->tx_len)) {
        copy = NS_MBEDTLS_BIO_TX_MAX - bio->tx_len;
    }
    if (copy == 0u) {
        return MBEDTLS_ERR_SSL_WANT_WRITE;
    }

    memcpy(bio->tx + bio->tx_len, buf, copy);
    bio->tx_len += copy;
    return (int)copy;
}

int ns_mbedtls_bio_recv(void *ctx, unsigned char *buf, size_t len)
{
    (void)ctx;
    (void)buf;
    (void)len;
    /* No peer yet. Plug in TCP recv here for a real TLS 1.3 server. */
    return MBEDTLS_ERR_SSL_WANT_READ;
}
