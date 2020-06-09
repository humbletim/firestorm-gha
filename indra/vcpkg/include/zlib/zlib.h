#pragma once

# if VCPKG_TOOLCHAIN
#     include <zlib.h>
# else
#     include <zlib/zlib.h>
# endif
