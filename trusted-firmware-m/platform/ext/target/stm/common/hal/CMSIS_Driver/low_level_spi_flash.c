/**
  ******************************************************************************
  * @file    low_level_spi_flash.c
  * @brief   W25Q32 NOR via STM32H5 SPI1 (PA5/PA6/PA7, CS PB2)
  ******************************************************************************
  */
#include "stm32hal.h"
#include "low_level_spi_flash.h"
#include "flash_layout.h"
#include "board.h"
#include <string.h>

#ifndef ARG_UNUSED
#define ARG_UNUSED(arg)  ((void)arg)
#endif

#define ARM_SPI_FLASH_DRV_VERSION   ARM_DRIVER_VERSION_MAJOR_MINOR(1, 0)

#define W25_CMD_WRITE_ENABLE        0x06U
#define W25_CMD_READ_STATUS         0x05U
#define W25_CMD_READ_DATA           0x03U
#define W25_CMD_PAGE_PROGRAM        0x02U
#define W25_CMD_SECTOR_ERASE_4K     0x20U
#define W25_CMD_JEDEC_ID            0x9FU
#define W25_STATUS_WIP              0x01U
#define W25_JEDEC_MANU              0xEFU
#define W25_JEDEC_TYPE              0x40U
#define W25_JEDEC_CAP               0x16U

#define SPI_XFER_TIMEOUT            200000U
#define SPI_WIP_TIMEOUT             2000000U

/*
 * BL2 is Secure: keep SPI1 + pins Secure and use the S alias.
 * Marking them NS here made CS (GPIOB_S write to an NS pin) a no-op, so JEDEC
 * failed and BL2 printed "Error while initializing Flash Interface".
 * SPE later sets SPI1 NS (target_cfg) so NSPE can program the NOR.
 */
#if defined(BL2)
#define W25_SPI              SPI1_S
#define W25_GPIO_SCK         GPIOA_S
#define W25_GPIO_MISO        GPIOA_S
#define W25_GPIO_MOSI        GPIOA_S
#define W25_GPIO_CS          GPIOB_S
#define W25_MARK_PINS_NS     0
#elif defined(__ARM_FEATURE_CMSE) && (__ARM_FEATURE_CMSE == 3U)
#define W25_SPI              SPI1_NS
#define W25_GPIO_SCK         GPIOA_NS
#define W25_GPIO_MISO        GPIOA_NS
#define W25_GPIO_MOSI        GPIOA_NS
#define W25_GPIO_CS          GPIOB_NS
#define W25_MARK_PINS_NS     1
#else
#define W25_SPI              SPI1
#define W25_GPIO_SCK         SPI1_FLASH_SCK_PORT
#define W25_GPIO_MISO        SPI1_FLASH_MISO_PORT
#define W25_GPIO_MOSI        SPI1_FLASH_MOSI_PORT
#define W25_GPIO_CS          SPI1_FLASH_CS_PORT
#define W25_MARK_PINS_NS     0
#endif

static const ARM_DRIVER_VERSION DriverVersion = {
    ARM_FLASH_API_VERSION,
    ARM_SPI_FLASH_DRV_VERSION
};

static const ARM_FLASH_CAPABILITIES DriverCapabilities = {
    0, /* event_ready */
    0, /* data_width 8-bit */
    0, /* erase_chip not supported */
    0  /* reserved */
};

static ARM_FLASH_INFO SPI_FLASH0_DEV_DATA = {
    .sector_info  = NULL,
    .sector_count = SPI_FLASH_TOTAL_SIZE / SPI_FLASH_SECTOR_SIZE,
    .sector_size  = SPI_FLASH_SECTOR_SIZE,
    .page_size    = SPI_FLASH_PAGE_SIZE,
    .program_unit = 1,
    .erased_value = 0xFF
};

static ARM_FLASH_STATUS SPI_FLASH0_STATUS = {0, 0, 0};
static uint8_t spi_inited;

static void cs_low(void)
{
    HAL_GPIO_WritePin(W25_GPIO_CS, SPI1_FLASH_CS_PIN, GPIO_PIN_RESET);
}

static void cs_high(void)
{
    HAL_GPIO_WritePin(W25_GPIO_CS, SPI1_FLASH_CS_PIN, GPIO_PIN_SET);
}

static int spi_hw_init(void)
{
    GPIO_InitTypeDef gpio = {0};
    SPI_TypeDef *spi = W25_SPI;
#if W25_MARK_PINS_NS
    GPIO_TypeDef *gpio_sck_cfg = GPIOA_S;
    GPIO_TypeDef *gpio_cs_cfg = GPIOB_S;
#else
    GPIO_TypeDef *gpio_sck_cfg = W25_GPIO_SCK;
    GPIO_TypeDef *gpio_cs_cfg = W25_GPIO_CS;
#endif

    __HAL_RCC_GPIOA_CLK_ENABLE();
    __HAL_RCC_GPIOB_CLK_ENABLE();
    __HAL_RCC_SPI1_CLK_ENABLE();
    /* H573 SPI1 kernel clock defaults to PLL1Q (enabled in SetSysClock). */
    __HAL_RCC_SPI1_CONFIG(RCC_SPI1CLKSOURCE_PLL1Q);

    gpio.Mode = GPIO_MODE_AF_PP;
    gpio.Pull = GPIO_NOPULL;
    gpio.Speed = GPIO_SPEED_FREQ_HIGH;
    gpio.Alternate = SPI1_FLASH_SCK_AF;
    gpio.Pin = SPI1_FLASH_SCK_PIN;
    HAL_GPIO_Init(gpio_sck_cfg, &gpio);

    gpio.Alternate = SPI1_FLASH_MISO_AF;
    gpio.Pin = SPI1_FLASH_MISO_PIN;
    gpio.Pull = GPIO_PULLUP;
    HAL_GPIO_Init(gpio_sck_cfg, &gpio);

    gpio.Alternate = SPI1_FLASH_MOSI_AF;
    gpio.Pin = SPI1_FLASH_MOSI_PIN;
    gpio.Pull = GPIO_NOPULL;
    HAL_GPIO_Init(gpio_sck_cfg, &gpio);

    gpio.Mode = GPIO_MODE_OUTPUT_PP;
    gpio.Pull = GPIO_PULLUP;
    gpio.Speed = GPIO_SPEED_FREQ_HIGH;
    gpio.Alternate = 0;
    gpio.Pin = SPI1_FLASH_CS_PIN;
    HAL_GPIO_Init(gpio_cs_cfg, &gpio);
    /* Drive CS on the same GPIO instance used for Init (S in BL2/SPE). */
    HAL_GPIO_WritePin(gpio_cs_cfg, SPI1_FLASH_CS_PIN, GPIO_PIN_SET);

#if W25_MARK_PINS_NS
    /* SPE only: NSPE programs NOR. AF was set on the Secure GPIO instance. */
    HAL_GPIO_ConfigPinAttributes(GPIOA_S, SPI1_FLASH_SCK_PIN, GPIO_PIN_NSEC);
    HAL_GPIO_ConfigPinAttributes(GPIOA_S, SPI1_FLASH_MISO_PIN, GPIO_PIN_NSEC);
    HAL_GPIO_ConfigPinAttributes(GPIOA_S, SPI1_FLASH_MOSI_PIN, GPIO_PIN_NSEC);
    HAL_GPIO_ConfigPinAttributes(GPIOB_S, SPI1_FLASH_CS_PIN, GPIO_PIN_NSEC);
    HAL_GTZC_TZSC_ConfigPeriphAttributes(GTZC_PERIPH_SPI1,
                                         GTZC_TZSC_PERIPH_NSEC | GTZC_TZSC_PERIPH_NPRIV);
#endif

    spi->CR1 = 0U;
    /* 8-bit frames, baud /32, software NSS, keep MOSI idle level */
    spi->CFG1 = (7U << SPI_CFG1_DSIZE_Pos) | SPI_CFG1_MBR_2;
    spi->CFG2 = SPI_CFG2_MASTER | SPI_CFG2_SSM | SPI_CFG2_AFCNTR;
    spi->CR1 = SPI_CR1_SSI;
    spi->IFCR = 0xFFFFFFFFU;

    return 0;
}

static int spi_xfer(const uint8_t *tx, uint8_t *rx, uint32_t len)
{
    SPI_TypeDef *spi = W25_SPI;
    uint32_t i;
    uint32_t timeout;

    if ((len == 0U) || (len > 0xFFFFU)) {
        return -1;
    }

    spi->CR1 &= ~SPI_CR1_SPE;
    spi->CR2 = len;
    spi->IFCR = 0xFFFFFFFFU;
    spi->CR1 |= SPI_CR1_SPE;
    spi->CR1 |= SPI_CR1_CSTART;

    for (i = 0U; i < len; i++) {
        timeout = SPI_XFER_TIMEOUT;
        while (((spi->SR & SPI_SR_TXP) == 0U) && (timeout != 0U)) {
            timeout--;
        }
        if (timeout == 0U) {
            spi->CR1 &= ~SPI_CR1_SPE;
            return -1;
        }
        *((volatile uint8_t *)&spi->TXDR) = (tx != NULL) ? tx[i] : 0xFFU;

        timeout = SPI_XFER_TIMEOUT;
        while (((spi->SR & SPI_SR_RXP) == 0U) && (timeout != 0U)) {
            timeout--;
        }
        if (timeout == 0U) {
            spi->CR1 &= ~SPI_CR1_SPE;
            return -1;
        }
        {
            uint8_t b = *((volatile uint8_t *)&spi->RXDR);
            if (rx != NULL) {
                rx[i] = b;
            }
        }
    }

    timeout = SPI_XFER_TIMEOUT;
    while (((spi->SR & SPI_SR_EOT) == 0U) && (timeout != 0U)) {
        timeout--;
    }
    spi->IFCR = SPI_IFCR_EOTC | SPI_IFCR_TXTFC;
    spi->CR1 &= ~SPI_CR1_SPE;
    return (timeout == 0U) ? -1 : 0;
}

static int w25_cmd(const uint8_t *cmd, uint32_t cmd_len,
                   const uint8_t *data, uint32_t data_len,
                   uint8_t *rx, uint32_t rx_len)
{
    uint8_t buf[16];
    int rc;

    if ((cmd_len + ((data != NULL) ? data_len : 0U) + rx_len) > sizeof(buf)) {
        /* Large payload: split into cmd then data in one CS window via two xfers
         * is not valid (CS would rise). Use the streaming path instead.
         */
        return -1;
    }

    memcpy(buf, cmd, cmd_len);
    if ((data != NULL) && (data_len != 0U)) {
        memcpy(&buf[cmd_len], data, data_len);
    }

    cs_low();
    if (rx_len != 0U) {
        uint8_t all[16 + 16];
        uint32_t total = cmd_len + rx_len;

        memcpy(all, buf, cmd_len);
        memset(&all[cmd_len], 0xFF, rx_len);
        rc = spi_xfer(all, all, total);
        if ((rc == 0) && (rx != NULL)) {
            memcpy(rx, &all[cmd_len], rx_len);
        }
    } else {
        rc = spi_xfer(buf, NULL, cmd_len + data_len);
    }
    cs_high();
    return rc;
}

static int w25_wait_ready(void)
{
    uint8_t cmd = W25_CMD_READ_STATUS;
    uint8_t sr;
    uint32_t timeout = SPI_WIP_TIMEOUT;

    while (timeout-- != 0U) {
        if (w25_cmd(&cmd, 1U, NULL, 0U, &sr, 1U) != 0) {
            return -1;
        }
        if ((sr & W25_STATUS_WIP) == 0U) {
            return 0;
        }
    }
    return -1;
}

static int w25_write_enable(void)
{
    uint8_t cmd = W25_CMD_WRITE_ENABLE;

    return w25_cmd(&cmd, 1U, NULL, 0U, NULL, 0U);
}

static int w25_stream_read(uint32_t addr, uint8_t *data, uint32_t len)
{
    uint8_t buf[4 + 256];
    uint32_t chunk;
    uint32_t done = 0U;

    while (done < len) {
        chunk = len - done;
        if (chunk > 256U) {
            chunk = 256U;
        }

        buf[0] = W25_CMD_READ_DATA;
        buf[1] = (uint8_t)((addr + done) >> 16);
        buf[2] = (uint8_t)((addr + done) >> 8);
        buf[3] = (uint8_t)(addr + done);
        memset(&buf[4], 0xFF, chunk);

        cs_low();
        if (spi_xfer(buf, buf, 4U + chunk) != 0) {
            cs_high();
            return -1;
        }
        cs_high();
        memcpy(&data[done], &buf[4], chunk);
        done += chunk;
    }
    return 0;
}

static int w25_page_program(uint32_t addr, const uint8_t *data, uint32_t len)
{
    uint8_t buf[4 + 256];

    if ((len == 0U) || (len > SPI_FLASH_PAGE_SIZE)) {
        return -1;
    }
    if (((addr & (SPI_FLASH_PAGE_SIZE - 1U)) + len) > SPI_FLASH_PAGE_SIZE) {
        return -1;
    }

    if (w25_write_enable() != 0) {
        return -1;
    }

    buf[0] = W25_CMD_PAGE_PROGRAM;
    buf[1] = (uint8_t)(addr >> 16);
    buf[2] = (uint8_t)(addr >> 8);
    buf[3] = (uint8_t)addr;
    memcpy(&buf[4], data, len);

    cs_low();
    if (spi_xfer(buf, NULL, 4U + len) != 0) {
        cs_high();
        return -1;
    }
    cs_high();
    return w25_wait_ready();
}

static int is_slot_range(uint32_t addr, uint32_t len)
{
    uint32_t end;
    uint32_t slot_end = FLASH_AREA_3_OFFSET + FLASH_AREA_3_SIZE - 1U;

    if (len == 0U) {
        return 0;
    }
    if (addr < FLASH_AREA_2_OFFSET) {
        return 0;
    }
    if (addr > (0xFFFFFFFFU - (len - 1U))) {
        return 0;
    }
    end = addr + len - 1U;
    if (end > slot_end) {
        return 0;
    }
    return 1;
}

static ARM_DRIVER_VERSION Flash_GetVersion(void)
{
    return DriverVersion;
}

static ARM_FLASH_CAPABILITIES Flash_GetCapabilities(void)
{
    return DriverCapabilities;
}

static int32_t Flash_Initialize(ARM_Flash_SignalEvent_t cb_event)
{
    uint8_t id[3] = {0};

    ARG_UNUSED(cb_event);
    if (spi_inited != 0U) {
        return ARM_DRIVER_OK;
    }
    SPI_FLASH0_STATUS.error = 0;
    SPI_FLASH0_STATUS.busy = 0;

    if (spi_hw_init() != 0) {
        SPI_FLASH0_STATUS.error = 1;
        return ARM_DRIVER_ERROR;
    }

    if (w25q32_read_jedec_id(id) != 0) {
        SPI_FLASH0_STATUS.error = 1;
        return ARM_DRIVER_ERROR;
    }

    if ((id[0] != W25_JEDEC_MANU) || (id[1] != W25_JEDEC_TYPE) ||
        (id[2] != W25_JEDEC_CAP)) {
        SPI_FLASH0_STATUS.error = 1;
        return ARM_DRIVER_ERROR;
    }

    spi_inited = 1U;
    return ARM_DRIVER_OK;
}

static int32_t Flash_Uninitialize(void)
{
    spi_inited = 0U;
    return ARM_DRIVER_OK;
}

static int32_t Flash_PowerControl(ARM_POWER_STATE state)
{
    ARG_UNUSED(state);
    return ARM_DRIVER_OK;
}

static int32_t Flash_ReadData(uint32_t addr, void *data, uint32_t cnt)
{
    if ((data == NULL) || (cnt == 0U) || (spi_inited == 0U)) {
        return ARM_DRIVER_ERROR_PARAMETER;
    }
    if ((addr + cnt) > SPI_FLASH_TOTAL_SIZE) {
        return ARM_DRIVER_ERROR_PARAMETER;
    }

    SPI_FLASH0_STATUS.busy = 1;
    if (w25_stream_read(addr, data, cnt) != 0) {
        SPI_FLASH0_STATUS.busy = 0;
        SPI_FLASH0_STATUS.error = 1;
        return ARM_DRIVER_ERROR;
    }
    SPI_FLASH0_STATUS.busy = 0;
    return (int32_t)cnt;
}

static int32_t Flash_ProgramData(uint32_t addr, const void *data, uint32_t cnt)
{
    const uint8_t *src = data;
    uint32_t remaining = cnt;
    uint32_t off = addr;
    uint32_t chunk;

    if ((data == NULL) || (cnt == 0U) || (spi_inited == 0U)) {
        return ARM_DRIVER_ERROR_PARAMETER;
    }
    if (!is_slot_range(addr, cnt)) {
        return ARM_DRIVER_ERROR_PARAMETER;
    }

    SPI_FLASH0_STATUS.busy = 1;
    while (remaining != 0U) {
        chunk = SPI_FLASH_PAGE_SIZE - (off & (SPI_FLASH_PAGE_SIZE - 1U));
        if (chunk > remaining) {
            chunk = remaining;
        }
        if (w25_page_program(off, src, chunk) != 0) {
            SPI_FLASH0_STATUS.busy = 0;
            SPI_FLASH0_STATUS.error = 1;
            return ARM_DRIVER_ERROR;
        }
        off += chunk;
        src += chunk;
        remaining -= chunk;
    }
    SPI_FLASH0_STATUS.busy = 0;
    return (int32_t)cnt;
}

static int32_t Flash_EraseSector(uint32_t addr)
{
    uint8_t cmd[4];

    if ((spi_inited == 0U) || ((addr % SPI_FLASH_SECTOR_SIZE) != 0U)) {
        return ARM_DRIVER_ERROR_PARAMETER;
    }
    if (!is_slot_range(addr, SPI_FLASH_SECTOR_SIZE)) {
        return ARM_DRIVER_ERROR_PARAMETER;
    }

    SPI_FLASH0_STATUS.busy = 1;
    if (w25_write_enable() != 0) {
        SPI_FLASH0_STATUS.busy = 0;
        SPI_FLASH0_STATUS.error = 1;
        return ARM_DRIVER_ERROR;
    }

    cmd[0] = W25_CMD_SECTOR_ERASE_4K;
    cmd[1] = (uint8_t)(addr >> 16);
    cmd[2] = (uint8_t)(addr >> 8);
    cmd[3] = (uint8_t)addr;
    if (w25_cmd(cmd, sizeof(cmd), NULL, 0U, NULL, 0U) != 0) {
        SPI_FLASH0_STATUS.busy = 0;
        SPI_FLASH0_STATUS.error = 1;
        return ARM_DRIVER_ERROR;
    }
    if (w25_wait_ready() != 0) {
        SPI_FLASH0_STATUS.busy = 0;
        SPI_FLASH0_STATUS.error = 1;
        return ARM_DRIVER_ERROR;
    }
    SPI_FLASH0_STATUS.busy = 0;
    return ARM_DRIVER_OK;
}

static int32_t Flash_EraseChip(void)
{
    return ARM_DRIVER_ERROR_UNSUPPORTED;
}

static ARM_FLASH_STATUS Flash_GetStatus(void)
{
    return SPI_FLASH0_STATUS;
}

static ARM_FLASH_INFO *Flash_GetInfo(void)
{
    return &SPI_FLASH0_DEV_DATA;
}

ARM_DRIVER_FLASH TFM_Driver_SPI_FLASH0 = {
    Flash_GetVersion,
    Flash_GetCapabilities,
    Flash_Initialize,
    Flash_Uninitialize,
    Flash_PowerControl,
    Flash_ReadData,
    Flash_ProgramData,
    Flash_EraseSector,
    Flash_EraseChip,
    Flash_GetStatus,
    Flash_GetInfo
};

int32_t w25q32_init(void)
{
    return Flash_Initialize(NULL);
}

int32_t w25q32_read(uint32_t addr, void *buf, uint32_t len)
{
    int32_t ret = Flash_ReadData(addr, buf, len);

    return (ret < 0) ? ret : ARM_DRIVER_OK;
}

int32_t w25q32_write(uint32_t addr, const void *buf, uint32_t len)
{
    int32_t ret = Flash_ProgramData(addr, buf, len);

    return (ret < 0) ? ret : ARM_DRIVER_OK;
}

int32_t w25q32_erase_4k(uint32_t addr)
{
    return Flash_EraseSector(addr);
}

int32_t w25q32_read_jedec_id(uint8_t id[3])
{
    uint8_t cmd = W25_CMD_JEDEC_ID;

    if (id == NULL) {
        return ARM_DRIVER_ERROR_PARAMETER;
    }
    if (w25_cmd(&cmd, 1U, NULL, 0U, id, 3U) != 0) {
        return ARM_DRIVER_ERROR;
    }
    return ARM_DRIVER_OK;
}
