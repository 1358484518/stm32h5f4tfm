/*
 * SPDX-FileCopyrightText: Copyright The TrustedFirmware-M Contributors
 *
 * SPDX-License-Identifier: BSD-3-Clause
 *
 */

#include "test_app.h"
#include "test_log.h"
#ifdef TFM_NS_REG_TEST
#include "non_secure_suites.h"
#endif
#include "os_wrapper/thread.h"
#include "ns_flash_size_probe.h"

/**
 * \brief Services test thread
 *
 */
__attribute__((noreturn))
void test_app(void *argument)
{
    UNUSED_VARIABLE(argument);

    /* Extra debug check only: large flash blob walk (does not replace tests). */
    ns_flash_size_probe();

#ifdef TFM_NS_REG_TEST
    ns_reg_test_start();
#endif

    /* Output EOT char for test environments like FVP. */
    LOG_MSG("\x04");

    /* End of test */
    os_wrapper_thread_exit();
}
