# Command-line build for the STM32H5F4 CubeIDE NS smoke app.
# Matches STM32CubeIDE/.cproject (MCU STM32H5F4xx, BL2_TRAILER_SIZE=0x3000).
#
#   make
#   make clean
#
# Output: build/tfm_ns.elf  build/tfm_ns.bin
# Sign (optional):  ./sign_kit/sign.sh build/tfm_ns.bin
# Flash with windows-tfm-tools or ./flash_stm32h5f4.sh — not spe/api_ns/*.sh.

CROSS   ?= arm-none-eabi-
CC      := $(CROSS)gcc
OBJCOPY := $(CROSS)objcopy
SIZE    := $(CROSS)size

BUILD   := build
TARGET  := $(BUILD)/tfm_ns
LDSCRIPT := spe/out/appli_ns.pp.ld
VENEERS := spe/api_ns/interface/lib/s_veneers.o

CPU := -mcpu=cortex-m33 -mthumb -mfpu=fpv5-sp-d16 -mfloat-abi=hard

CPPFLAGS := \
	-DUSE_HAL_DRIVER \
	-DSTM32H5F4xx \
	-DDOMAIN_NS=1 \
	-DCONFIG_TFM_FLOAT_ABI=2 \
	-DCONFIG_TFM_ENABLE_CP10CP11 \
	-DPLATFORM_DEFAULT_CRYPTO_KEYS \
	-DCONFIG_TFM_USE_TRUSTZONE \
	-DTFM_ISOLATION_LEVEL=1 \
	-DTFM_PARTITION_CRYPTO \
	-DTFM_PARTITION_INTERNAL_TRUSTED_STORAGE \
	-DTFM_PARTITION_PROTECTED_STORAGE \
	-DTFM_PARTITION_FIRMWARE_UPDATE \
	-DTFM_PARTITION_INITIAL_ATTESTATION \
	-DTFM_PARTITION_PLATFORM \
	-DTFM_PSA_CRYPTO_CLIENT_ONLY \
	-DTF_PSA_CRYPTO_CONFIG_FILE='"mbedtls/tf_psa_crypto_config.h"' \
	-DTARGET_CONFIG_HEADER_FILE='"config_tfm_target.h"' \
	-DBL2 \
	-DBL2_HEADER_SIZE=0x400 \
	-DBL2_TRAILER_SIZE=0x3000 \
	-DMCUBOOT_IMAGE_NUMBER=2 \
	-DTFM_NS_LOG \
	-DNDEBUG \
	-Ispe/api_ns/interface/include \
	-Ispe/api_ns/interface/include/crypto_keys \
	-Ispe/api_ns/platform/include \
	-Ispe/api_ns/platform/boards \
	-Ispe/api_ns/platform/Device/Include \
	-Ispe/api_ns/platform/ext/cmsis/Include \
	-Ispe/api_ns/platform/ext/cmsis/Include/m-profile \
	-Ispe/api_ns/platform/ext/common \
	-Ispe/api_ns/platform/hal/Inc \
	-Ins_app

CFLAGS := $(CPU) -O2 -ffunction-sections -fdata-sections -Wall -fno-builtin

LDFLAGS := $(CPU) -T$(LDSCRIPT) -Wl,--gc-sections --specs=nano.specs --specs=nosys.specs -Wl,-Map=$(TARGET).map

NS_APP_SRCS := \
	ns_app/main.c \
	ns_app/tfm_log_raw.c \
	ns_app/syscalls_stub.c \
	ns_app/platform_init_def.c

TFM_SRCS := $(wildcard ns_app/tfm_src/*.c)

SRCS := $(NS_APP_SRCS) $(TFM_SRCS)
OBJS := $(patsubst %.c,$(BUILD)/%.o,$(SRCS))

.PHONY: all clean size

all: $(TARGET).bin size

$(BUILD)/%.o: %.c
	@mkdir -p $(dir $@)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

$(TARGET).elf: $(OBJS) $(VENEERS) $(LDSCRIPT)
	@mkdir -p $(dir $@)
	$(CC) $(LDFLAGS) -o $@ $(OBJS) $(VENEERS)

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

size: $(TARGET).elf
	$(SIZE) -A $<

clean:
	rm -rf $(BUILD)
