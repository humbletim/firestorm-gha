project(boost_filesystem_patch)
include(00-Common)
include(Boost)

message(STATUS ======= boost_filesystem_codecvt_patch)
add_definitions(/Zc:wchar_t-)
add_library(boost_filesystem_patch SHARED filesystem-codecvt-patch.cpp)
set(BOOST_FILESYTEM_PATCH_LIBRARY boost_filesystem_patch)
