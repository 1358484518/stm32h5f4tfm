################################################################################
# Automatically-generated file. Do not edit!
# Toolchain: GNU Tools for STM32 (14.3.rel1)
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../spe/api_ns/interface/src/os_wrapper/tfm_ns_interface_bare_metal.c \
../spe/api_ns/interface/src/os_wrapper/tfm_ns_interface_rtos.c 

OBJS += \
./spe/api_ns/interface/src/os_wrapper/tfm_ns_interface_bare_metal.o \
./spe/api_ns/interface/src/os_wrapper/tfm_ns_interface_rtos.o 

C_DEPS += \
./spe/api_ns/interface/src/os_wrapper/tfm_ns_interface_bare_metal.d \
./spe/api_ns/interface/src/os_wrapper/tfm_ns_interface_rtos.d 


# Each subdirectory must supply rules for building sources it contributes
spe/api_ns/interface/src/os_wrapper/%.o spe/api_ns/interface/src/os_wrapper/%.su spe/api_ns/interface/src/os_wrapper/%.cyclo: ../spe/api_ns/interface/src/os_wrapper/%.c spe/api_ns/interface/src/os_wrapper/subdir.mk
	arm-none-eabi-gcc "$<" -mcpu=cortex-m33 -std=gnu11 -g3 -DDEBUG -DUSE_HAL_DRIVER -DSTM32H573xx -DDOMAIN_NS=1 -DCONFIG_TFM_FLOAT_ABI=2 -DCONFIG_TFM_ENABLE_CP10CP11 -DPLATFORM_DEFAULT_CRYPTO_KEYS -DCONFIG_TFM_USE_TRUSTZONE -DTFM_ISOLATION_LEVEL=1 -DTFM_PARTITION_CRYPTO -DTFM_PARTITION_INTERNAL_TRUSTED_STORAGE -DTFM_PARTITION_PROTECTED_STORAGE -DTFM_PARTITION_FIRMWARE_UPDATE -DTFM_PARTITION_INITIAL_ATTESTATION -DTFM_PARTITION_PLATFORM -DTFM_PSA_CRYPTO_CLIENT_ONLY '-DTF_PSA_CRYPTO_CONFIG_FILE="mbedtls/tf_psa_crypto_config.h"' '-DTARGET_CONFIG_HEADER_FILE="config_tfm_target.h"' -DBL2 -DBL2_HEADER_SIZE=0x400 -DBL2_TRAILER_SIZE=0x2000 -DMCUBOOT_IMAGE_NUMBER=2 -DTFM_NS_LOG -DNDEBUG -c -I../spe/api_ns/interface/include -I../spe/api_ns/interface/include/crypto_keys -I../spe/api_ns/platform/include -I../spe/api_ns/platform/boards -I../spe/api_ns/platform/Device/Include -I../spe/api_ns/platform/ext/cmsis/Include -I../spe/api_ns/platform/ext/cmsis/Include/m-profile -I../spe/api_ns/platform/ext/common -I../spe/api_ns/platform/hal/Inc -I"C:/Users/13584/Desktop/tfmproject/tfmcubeideproject/STM32CubeIDE/ns_app" -O0 -ffunction-sections -fdata-sections -Wall -fstack-usage -fcyclomatic-complexity -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv5-sp-d16 -mfloat-abi=hard -mthumb -o "$@"

clean: clean-spe-2f-api_ns-2f-interface-2f-src-2f-os_wrapper

clean-spe-2f-api_ns-2f-interface-2f-src-2f-os_wrapper:
	-$(RM) ./spe/api_ns/interface/src/os_wrapper/tfm_ns_interface_bare_metal.cyclo ./spe/api_ns/interface/src/os_wrapper/tfm_ns_interface_bare_metal.d ./spe/api_ns/interface/src/os_wrapper/tfm_ns_interface_bare_metal.o ./spe/api_ns/interface/src/os_wrapper/tfm_ns_interface_bare_metal.su ./spe/api_ns/interface/src/os_wrapper/tfm_ns_interface_rtos.cyclo ./spe/api_ns/interface/src/os_wrapper/tfm_ns_interface_rtos.d ./spe/api_ns/interface/src/os_wrapper/tfm_ns_interface_rtos.o ./spe/api_ns/interface/src/os_wrapper/tfm_ns_interface_rtos.su

.PHONY: clean-spe-2f-api_ns-2f-interface-2f-src-2f-os_wrapper

