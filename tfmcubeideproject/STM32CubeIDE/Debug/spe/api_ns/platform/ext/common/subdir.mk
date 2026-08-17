################################################################################
# Automatically-generated file. Do not edit!
# Toolchain: GNU Tools for STM32 (14.3.rel1)
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../spe/api_ns/platform/ext/common/bl2_hal_multisig.c \
../spe/api_ns/platform/ext/common/boot_hal_bl1_1.c \
../spe/api_ns/platform/ext/common/boot_hal_bl1_2.c \
../spe/api_ns/platform/ext/common/boot_hal_bl2.c \
../spe/api_ns/platform/ext/common/exception_info.c \
../spe/api_ns/platform/ext/common/faults.c \
../spe/api_ns/platform/ext/common/mem_check_v6m_v7m.c \
../spe/api_ns/platform/ext/common/mpc_ppc_faults.c \
../spe/api_ns/platform/ext/common/provisioning.c \
../spe/api_ns/platform/ext/common/syscalls_stub.c \
../spe/api_ns/platform/ext/common/test_interrupt.c \
../spe/api_ns/platform/ext/common/tfm_assert.c \
../spe/api_ns/platform/ext/common/tfm_boot_measurement.c \
../spe/api_ns/platform/ext/common/tfm_fatal_error.c \
../spe/api_ns/platform/ext/common/tfm_hal_isolation_v8m.c \
../spe/api_ns/platform/ext/common/tfm_hal_its.c \
../spe/api_ns/platform/ext/common/tfm_hal_nvic.c \
../spe/api_ns/platform/ext/common/tfm_hal_platform_v8m.c \
../spe/api_ns/platform/ext/common/tfm_hal_ps.c \
../spe/api_ns/platform/ext/common/tfm_hal_reset_halt.c \
../spe/api_ns/platform/ext/common/tfm_hal_sp_logdev_periph.c \
../spe/api_ns/platform/ext/common/tfm_hal_spm_logdev_peripheral.c \
../spe/api_ns/platform/ext/common/tfm_interrupts.c \
../spe/api_ns/platform/ext/common/tfm_sanitize_handlers.c \
../spe/api_ns/platform/ext/common/uart_stdout.c 

OBJS += \
./spe/api_ns/platform/ext/common/bl2_hal_multisig.o \
./spe/api_ns/platform/ext/common/boot_hal_bl1_1.o \
./spe/api_ns/platform/ext/common/boot_hal_bl1_2.o \
./spe/api_ns/platform/ext/common/boot_hal_bl2.o \
./spe/api_ns/platform/ext/common/exception_info.o \
./spe/api_ns/platform/ext/common/faults.o \
./spe/api_ns/platform/ext/common/mem_check_v6m_v7m.o \
./spe/api_ns/platform/ext/common/mpc_ppc_faults.o \
./spe/api_ns/platform/ext/common/provisioning.o \
./spe/api_ns/platform/ext/common/syscalls_stub.o \
./spe/api_ns/platform/ext/common/test_interrupt.o \
./spe/api_ns/platform/ext/common/tfm_assert.o \
./spe/api_ns/platform/ext/common/tfm_boot_measurement.o \
./spe/api_ns/platform/ext/common/tfm_fatal_error.o \
./spe/api_ns/platform/ext/common/tfm_hal_isolation_v8m.o \
./spe/api_ns/platform/ext/common/tfm_hal_its.o \
./spe/api_ns/platform/ext/common/tfm_hal_nvic.o \
./spe/api_ns/platform/ext/common/tfm_hal_platform_v8m.o \
./spe/api_ns/platform/ext/common/tfm_hal_ps.o \
./spe/api_ns/platform/ext/common/tfm_hal_reset_halt.o \
./spe/api_ns/platform/ext/common/tfm_hal_sp_logdev_periph.o \
./spe/api_ns/platform/ext/common/tfm_hal_spm_logdev_peripheral.o \
./spe/api_ns/platform/ext/common/tfm_interrupts.o \
./spe/api_ns/platform/ext/common/tfm_sanitize_handlers.o \
./spe/api_ns/platform/ext/common/uart_stdout.o 

C_DEPS += \
./spe/api_ns/platform/ext/common/bl2_hal_multisig.d \
./spe/api_ns/platform/ext/common/boot_hal_bl1_1.d \
./spe/api_ns/platform/ext/common/boot_hal_bl1_2.d \
./spe/api_ns/platform/ext/common/boot_hal_bl2.d \
./spe/api_ns/platform/ext/common/exception_info.d \
./spe/api_ns/platform/ext/common/faults.d \
./spe/api_ns/platform/ext/common/mem_check_v6m_v7m.d \
./spe/api_ns/platform/ext/common/mpc_ppc_faults.d \
./spe/api_ns/platform/ext/common/provisioning.d \
./spe/api_ns/platform/ext/common/syscalls_stub.d \
./spe/api_ns/platform/ext/common/test_interrupt.d \
./spe/api_ns/platform/ext/common/tfm_assert.d \
./spe/api_ns/platform/ext/common/tfm_boot_measurement.d \
./spe/api_ns/platform/ext/common/tfm_fatal_error.d \
./spe/api_ns/platform/ext/common/tfm_hal_isolation_v8m.d \
./spe/api_ns/platform/ext/common/tfm_hal_its.d \
./spe/api_ns/platform/ext/common/tfm_hal_nvic.d \
./spe/api_ns/platform/ext/common/tfm_hal_platform_v8m.d \
./spe/api_ns/platform/ext/common/tfm_hal_ps.d \
./spe/api_ns/platform/ext/common/tfm_hal_reset_halt.d \
./spe/api_ns/platform/ext/common/tfm_hal_sp_logdev_periph.d \
./spe/api_ns/platform/ext/common/tfm_hal_spm_logdev_peripheral.d \
./spe/api_ns/platform/ext/common/tfm_interrupts.d \
./spe/api_ns/platform/ext/common/tfm_sanitize_handlers.d \
./spe/api_ns/platform/ext/common/uart_stdout.d 


# Each subdirectory must supply rules for building sources it contributes
spe/api_ns/platform/ext/common/%.o spe/api_ns/platform/ext/common/%.su spe/api_ns/platform/ext/common/%.cyclo: ../spe/api_ns/platform/ext/common/%.c spe/api_ns/platform/ext/common/subdir.mk
	arm-none-eabi-gcc "$<" -mcpu=cortex-m33 -std=gnu11 -g3 -DDEBUG -DUSE_HAL_DRIVER -DSTM32H573xx -DDOMAIN_NS=1 -DCONFIG_TFM_FLOAT_ABI=2 -DCONFIG_TFM_ENABLE_CP10CP11 -DPLATFORM_DEFAULT_CRYPTO_KEYS -DCONFIG_TFM_USE_TRUSTZONE -DTFM_ISOLATION_LEVEL=1 -DTFM_PARTITION_CRYPTO -DTFM_PARTITION_INTERNAL_TRUSTED_STORAGE -DTFM_PARTITION_PROTECTED_STORAGE -DTFM_PARTITION_FIRMWARE_UPDATE -DTFM_PARTITION_INITIAL_ATTESTATION -DTFM_PARTITION_PLATFORM -DTFM_PSA_CRYPTO_CLIENT_ONLY '-DTF_PSA_CRYPTO_CONFIG_FILE="mbedtls/tf_psa_crypto_config.h"' '-DTARGET_CONFIG_HEADER_FILE="config_tfm_target.h"' -DBL2 -DBL2_HEADER_SIZE=0x400 -DBL2_TRAILER_SIZE=0x2000 -DMCUBOOT_IMAGE_NUMBER=2 -DTFM_NS_LOG -DNDEBUG -c -I../spe/api_ns/interface/include -I../spe/api_ns/interface/include/crypto_keys -I../spe/api_ns/platform/include -I../spe/api_ns/platform/boards -I../spe/api_ns/platform/Device/Include -I../spe/api_ns/platform/ext/cmsis/Include -I../spe/api_ns/platform/ext/cmsis/Include/m-profile -I../spe/api_ns/platform/ext/common -I../spe/api_ns/platform/hal/Inc -I"C:/Users/13584/Desktop/tfmproject/tfmcubeideproject/STM32CubeIDE/ns_app" -O0 -ffunction-sections -fdata-sections -Wall -fstack-usage -fcyclomatic-complexity -MMD -MP -MF"$(@:%.o=%.d)" -MT"$@" --specs=nano.specs -mfpu=fpv5-sp-d16 -mfloat-abi=hard -mthumb -o "$@"

clean: clean-spe-2f-api_ns-2f-platform-2f-ext-2f-common

clean-spe-2f-api_ns-2f-platform-2f-ext-2f-common:
	-$(RM) ./spe/api_ns/platform/ext/common/bl2_hal_multisig.cyclo ./spe/api_ns/platform/ext/common/bl2_hal_multisig.d ./spe/api_ns/platform/ext/common/bl2_hal_multisig.o ./spe/api_ns/platform/ext/common/bl2_hal_multisig.su ./spe/api_ns/platform/ext/common/boot_hal_bl1_1.cyclo ./spe/api_ns/platform/ext/common/boot_hal_bl1_1.d ./spe/api_ns/platform/ext/common/boot_hal_bl1_1.o ./spe/api_ns/platform/ext/common/boot_hal_bl1_1.su ./spe/api_ns/platform/ext/common/boot_hal_bl1_2.cyclo ./spe/api_ns/platform/ext/common/boot_hal_bl1_2.d ./spe/api_ns/platform/ext/common/boot_hal_bl1_2.o ./spe/api_ns/platform/ext/common/boot_hal_bl1_2.su ./spe/api_ns/platform/ext/common/boot_hal_bl2.cyclo ./spe/api_ns/platform/ext/common/boot_hal_bl2.d ./spe/api_ns/platform/ext/common/boot_hal_bl2.o ./spe/api_ns/platform/ext/common/boot_hal_bl2.su ./spe/api_ns/platform/ext/common/exception_info.cyclo ./spe/api_ns/platform/ext/common/exception_info.d ./spe/api_ns/platform/ext/common/exception_info.o ./spe/api_ns/platform/ext/common/exception_info.su ./spe/api_ns/platform/ext/common/faults.cyclo ./spe/api_ns/platform/ext/common/faults.d ./spe/api_ns/platform/ext/common/faults.o ./spe/api_ns/platform/ext/common/faults.su ./spe/api_ns/platform/ext/common/mem_check_v6m_v7m.cyclo ./spe/api_ns/platform/ext/common/mem_check_v6m_v7m.d ./spe/api_ns/platform/ext/common/mem_check_v6m_v7m.o ./spe/api_ns/platform/ext/common/mem_check_v6m_v7m.su ./spe/api_ns/platform/ext/common/mpc_ppc_faults.cyclo ./spe/api_ns/platform/ext/common/mpc_ppc_faults.d ./spe/api_ns/platform/ext/common/mpc_ppc_faults.o ./spe/api_ns/platform/ext/common/mpc_ppc_faults.su ./spe/api_ns/platform/ext/common/provisioning.cyclo ./spe/api_ns/platform/ext/common/provisioning.d ./spe/api_ns/platform/ext/common/provisioning.o ./spe/api_ns/platform/ext/common/provisioning.su ./spe/api_ns/platform/ext/common/syscalls_stub.cyclo ./spe/api_ns/platform/ext/common/syscalls_stub.d ./spe/api_ns/platform/ext/common/syscalls_stub.o ./spe/api_ns/platform/ext/common/syscalls_stub.su ./spe/api_ns/platform/ext/common/test_interrupt.cyclo ./spe/api_ns/platform/ext/common/test_interrupt.d ./spe/api_ns/platform/ext/common/test_interrupt.o ./spe/api_ns/platform/ext/common/test_interrupt.su ./spe/api_ns/platform/ext/common/tfm_assert.cyclo ./spe/api_ns/platform/ext/common/tfm_assert.d ./spe/api_ns/platform/ext/common/tfm_assert.o ./spe/api_ns/platform/ext/common/tfm_assert.su ./spe/api_ns/platform/ext/common/tfm_boot_measurement.cyclo ./spe/api_ns/platform/ext/common/tfm_boot_measurement.d ./spe/api_ns/platform/ext/common/tfm_boot_measurement.o ./spe/api_ns/platform/ext/common/tfm_boot_measurement.su ./spe/api_ns/platform/ext/common/tfm_fatal_error.cyclo ./spe/api_ns/platform/ext/common/tfm_fatal_error.d ./spe/api_ns/platform/ext/common/tfm_fatal_error.o ./spe/api_ns/platform/ext/common/tfm_fatal_error.su ./spe/api_ns/platform/ext/common/tfm_hal_isolation_v8m.cyclo ./spe/api_ns/platform/ext/common/tfm_hal_isolation_v8m.d ./spe/api_ns/platform/ext/common/tfm_hal_isolation_v8m.o ./spe/api_ns/platform/ext/common/tfm_hal_isolation_v8m.su ./spe/api_ns/platform/ext/common/tfm_hal_its.cyclo ./spe/api_ns/platform/ext/common/tfm_hal_its.d ./spe/api_ns/platform/ext/common/tfm_hal_its.o ./spe/api_ns/platform/ext/common/tfm_hal_its.su ./spe/api_ns/platform/ext/common/tfm_hal_nvic.cyclo ./spe/api_ns/platform/ext/common/tfm_hal_nvic.d ./spe/api_ns/platform/ext/common/tfm_hal_nvic.o ./spe/api_ns/platform/ext/common/tfm_hal_nvic.su ./spe/api_ns/platform/ext/common/tfm_hal_platform_v8m.cyclo ./spe/api_ns/platform/ext/common/tfm_hal_platform_v8m.d ./spe/api_ns/platform/ext/common/tfm_hal_platform_v8m.o ./spe/api_ns/platform/ext/common/tfm_hal_platform_v8m.su ./spe/api_ns/platform/ext/common/tfm_hal_ps.cyclo ./spe/api_ns/platform/ext/common/tfm_hal_ps.d ./spe/api_ns/platform/ext/common/tfm_hal_ps.o ./spe/api_ns/platform/ext/common/tfm_hal_ps.su ./spe/api_ns/platform/ext/common/tfm_hal_reset_halt.cyclo ./spe/api_ns/platform/ext/common/tfm_hal_reset_halt.d ./spe/api_ns/platform/ext/common/tfm_hal_reset_halt.o ./spe/api_ns/platform/ext/common/tfm_hal_reset_halt.su ./spe/api_ns/platform/ext/common/tfm_hal_sp_logdev_periph.cyclo ./spe/api_ns/platform/ext/common/tfm_hal_sp_logdev_periph.d ./spe/api_ns/platform/ext/common/tfm_hal_sp_logdev_periph.o ./spe/api_ns/platform/ext/common/tfm_hal_sp_logdev_periph.su ./spe/api_ns/platform/ext/common/tfm_hal_spm_logdev_peripheral.cyclo ./spe/api_ns/platform/ext/common/tfm_hal_spm_logdev_peripheral.d ./spe/api_ns/platform/ext/common/tfm_hal_spm_logdev_peripheral.o ./spe/api_ns/platform/ext/common/tfm_hal_spm_logdev_peripheral.su ./spe/api_ns/platform/ext/common/tfm_interrupts.cyclo ./spe/api_ns/platform/ext/common/tfm_interrupts.d ./spe/api_ns/platform/ext/common/tfm_interrupts.o ./spe/api_ns/platform/ext/common/tfm_interrupts.su ./spe/api_ns/platform/ext/common/tfm_sanitize_handlers.cyclo ./spe/api_ns/platform/ext/common/tfm_sanitize_handlers.d ./spe/api_ns/platform/ext/common/tfm_sanitize_handlers.o ./spe/api_ns/platform/ext/common/tfm_sanitize_handlers.su ./spe/api_ns/platform/ext/common/uart_stdout.cyclo ./spe/api_ns/platform/ext/common/uart_stdout.d ./spe/api_ns/platform/ext/common/uart_stdout.o ./spe/api_ns/platform/ext/common/uart_stdout.su

.PHONY: clean-spe-2f-api_ns-2f-platform-2f-ext-2f-common

