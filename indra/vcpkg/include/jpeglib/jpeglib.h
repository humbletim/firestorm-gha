#pragma once

# if VCPKG_TOOLCHAIN
#     include <jpeglib.h>
# else
#     include <jpeglib/jpeglib.h>
# endif
