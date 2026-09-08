/**
  ******************************************************************************
  * @file    low_level_spi_flash.h
  * @brief   CMSIS Flash driver for W25Q32 on STM32H573 SPI1
  ******************************************************************************
  */
#ifndef __LOW_LEVEL_SPI_FLASH_H
#define __LOW_LEVEL_SPI_FLASH_H

#ifdef __cplusplus
extern "C" {
#endif

#include "Driver_Flash.h"

extern ARM_DRIVER_FLASH TFM_Driver_SPI_FLASH0;

/*
 * NS download helpers (same backend as BL2/MCUboot).
 * Offsets: SPI_FLASH_S_UPDATE_OFFSET (512 KB), SPI_FLASH_NS_UPDATE_OFFSET (1 MB)
 * in flash_layout.h. Pins: SPI1 PA5/PA6/PA7, CS PB2.
 */
int32_t w25q32_init(void);
int32_t w25q32_read(uint32_t addr, void *buf, uint32_t len);
int32_t w25q32_write(uint32_t addr, const void *buf, uint32_t len);
int32_t w25q32_erase_4k(uint32_t addr);
int32_t w25q32_read_jedec_id(uint8_t id[3]);

#ifdef __cplusplus
}
#endif

#endif /* __LOW_LEVEL_SPI_FLASH_H */
