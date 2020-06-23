#pragma once

# if VCPKG_TOOLCHAIN
#     include <client/windows/handler/exception_handler.h>
# else
#     include <google_breakpad/exception_handler.h>
# endif
