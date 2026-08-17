################################################################################
# Automatically-generated file. Do not edit!
# Toolchain: GNU Tools for STM32 (14.3.rel1)
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../spe/api_ns/platform/ext/common/template/attest_hal.c \
../spe/api_ns/platform/ext/common/template/crypto_keys.c \
../spe/api_ns/platform/ext/common/template/crypto_nv_seed.c \
../spe/api_ns/platform/ext/common/template/flash_otp_nv_counters_backend.c \
../spe/api_ns/platform/ext/common/template/nv_counters.c \
../spe/api_ns/platform/ext/common/template/otp_flash.c \
../spe/api_ns/platform/ext/common/template/tfm_fih_platform.c \
../spe/api_ns/platform/ext/common/template/tfm_hal_its_encryption.c \
../spe/api_ns/platform/ext/common/template/tfm_rotpk.c \
../spe/api_ns/platform/ext/common/template/tfm_shared_measurement_data.c 

OBJS += \
./spe/api_ns/platform/ext/common/template/attest_hal.o \
./spe/api_ns/platform/ext/common/template/crypto_keys.o \
./spe/api_ns/platform/ext/common/template/crypto_nv_seed.o \
./spe/api_ns/platform/ext/common/template/flash_otp_nv_counters_backend.o \
./spe/api_ns/platform/ext/common/template/nv_counters.o \
./spe/api_ns/platform/ext/common/template/otp_flash.o \
./spe/api_ns/platform/ext/common/template/tfm_fih_platform.o \
./spe/api_ns/platform/ext/common/template/tfm_hal_its_encryption.o \
./spe/api_ns/platform/ext/common/template/tfm_rotpk.o \
./spe/api_ns/platform/ext/common/template/tfm_shared_measurement_data.o 

C_DEPS += \
./spe/api_ns/platform/ext/common/template/attest_hal.d \
./spe/api_ns/platform/ext/common/template/crypto_keys.d \
./spe/api_ns/platform/ext/common/template/crypto_nv_seed.d \
./spe/api_ns/platform/ext/common/template/flash_otp_nv_counters_backend.d \
./spe/api_ns/platform/ext/common/template/nv_counters.d \
./spe/api_ns/platform/ext/common/template/otp_flash.d \
./spe/api_ns/platform/ext/common/template/tfm_fih_platform.d \
./spe/api_ns/platform/ext/common/template/tfm_hal_its_encryption.d \
./spe/api_ns/platform/ext/common/template/tfm_rotpk.d \
./spe/api_ns/platform/ext/common/template/tfm_shared_measurement_data.d 


# Each subdirectory must supply rules for building sources it contributes
spe/api_ns/platform/ext/common/template/%.o spe/api_ns/platform/ext/common/template/%.su spe/api_ns/platform/ext/common/template/%.cyclo: ../spe/api_ns/platform/ext/common/template/%.c spe/api_ns/platform/ext/common/template/subdir.mk
	arm-none-eabi-gcc "$<" -mcpu=cortex-m33 -std=gnu11 -g3 -DDEBUG -DUSE_HAL_DRIVER -DSTM32H573xx -DDOMAIN_NS=1 -DCONFIG_TFM_FLOAT_ABI=2 -DCONFIG_TFM_ENABLE_CP10CP11 -DPLATFORM_DEFAULT_CRYPTO_KEYS -DCONFIG_TFM_USE_TRUSTZONE -DTFM_ISOLATION_LEVEL=1 -DTFM_PARTITION_CRYPTO -DTFM_PARTITION_INTERNAL_TRUSTED_STORAGE -DTFM_PARTITION_PROTECTED_STORAGE -DTFM_PARTITION_FIRMWARE_UPDATE -DTFM_PARTITION_INITIAL_ATTESTATION -DTFM_PARTITION_PLATFORM -DTFM_PSA_CRYPTO_CLIENT_ONLY '-DTF_PSA_CRYPTO_CONFIG_FILE="mbedtls/tf_psa_crypto_config.h"' '-DTARGET_CONFIG_HEADER_FILE="config_tfm_target.h"' -DBL2 -DBL2_HEADER_SIZE=0x400 -DBL2_TRAILER_SIZE=0x2000 -DMCUBOOT_IMAGE_NUMBER=2 -DTFM_NS_LOG -DNDEBUG -c -I../spe/api_ns/interface/include -I../spe/api_ns/interface/include/crypto_keys -I../spe/api_ns/platform/include -I../spe/api_ns/platform/boards -I../spe/api_ns/platform/Device/Include -I../spe/api_ns/platform/ext/cmsis/Include -I../spe/api_ns/platform/ext/cmsis/Include/m-profile -I../spe/api_ns/platform/ext/common -I../spe/api_ns/platform/hal/Inc -I"C:/Users/13584/Desktop/tfmproject/tfmcubeideproject/STM32CubeIDE/ns_app" -O0 -ffunction-sections -fdata-sections -Wall -fstack-usage -fcyclomatic-complexity -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv5-sp-d16 -mfloat-abi=hard -mthumb -o "$@"

clean: clean-spe-2f-api_ns-2f-platform-2f-ext-2f-common-2f-template

clean-spe-2f-api_ns-2f-platform-2f-ext-2f-common-2f-template:
	-$(RM) ./spe/api_ns/platform/ext/common/template/attest_hal.cyclo ./spe/api_ns/platform/ext/common/template/attest_hal.d ./spe/api_ns/platform/ext/common/template/attest_hal.o ./spe/api_ns/platform/ext/common/template/attest_hal.su ./spe/api_ns/platform/ext/common/template/crypto_keys.cyclo ./spe/api_ns/platform/ext/common/template/crypto_keys.d ./spe/api_ns/platform/ext/common/template/crypto_keys.o ./spe/api_ns/platform/ext/common/template/crypto_keys.su ./spe/api_ns/platform/ext/common/template/crypto_nv_seed.cyclo ./spe/api_ns/platform/ext/common/template/crypto_nv_seed.d ./spe/api_ns/platform/ext/common/template/crypto_nv_seed.o ./spe/api_ns/platform/ext/common/template/crypto_nv_seed.su ./spe/api_ns/platform/ext/common/template/flash_otp_nv_counters_backend.cyclo ./spe/api_ns/platform/ext/common/template/flash_otp_nv_counters_backend.d ./spe/api_ns/platform/ext/common/template/flash_otp_nv_counters_backend.o ./spe/api_ns/platform/ext/common/template/flash_otp_nv_counters_backend.su ./spe/api_ns/platform/ext/common/template/nv_counters.cyclo ./spe/api_ns/platform/ext/common/template/nv_counters.d ./spe/api_ns/platform/ext/common/template/nv_counters.o ./spe/api_ns/platform/ext/common/template/nv_counters.su ./spe/api_ns/platform/ext/common/template/otp_flash.cyclo ./spe/api_ns/platform/ext/common/template/otp_flash.d ./spe/api_ns/platform/ext/common/template/otp_flash.o ./spe/api_ns/platform/ext/common/template/otp_flash.su ./spe/api_ns/platform/ext/common/template/tfm_fih_platform.cyclo ./spe/api_ns/platform/ext/common/template/tfm_fih_platform.d ./spe/api_ns/platform/ext/common/template/tfm_fih_platform.o ./spe/api_ns/platform/ext/common/template/tfm_fih_platform.su ./spe/api_ns/platform/ext/common/template/tfm_hal_its_encryption.cyclo ./spe/api_ns/platform/ext/common/template/tfm_hal_its_encryption.d ./spe/api_ns/platform/ext/common/template/tfm_hal_its_encryption.o ./spe/api_ns/platform/ext/common/template/tfm_hal_its_encryption.su ./spe/api_ns/platform/ext/common/template/tfm_rotpk.cyclo ./spe/api_ns/platform/ext/common/template/tfm_rotpk.d ./spe/api_ns/platform/ext/common/template/tfm_rotpk.o ./spe/api_ns/platform/ext/common/template/tfm_rotpk.su ./spe/api_ns/platform/ext/common/template/tfm_shared_measurement_data.cyclo ./spe/api_ns/platform/ext/common/template/tfm_shared_measurement_data.d ./spe/api_ns/platform/ext/common/template/tfm_shared_measurement_data.o ./spe/api_ns/platform/ext/common/template/tfm_shared_measurement_data.su

.PHONY: clean-spe-2f-api_ns-2f-platform-2f-ext-2f-common-2f-template

