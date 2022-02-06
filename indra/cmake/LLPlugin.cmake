# -*- cmake -*-


set(LLPLUGIN_INCLUDE_DIRS
    ${LIBS_OPEN_DIR}/llplugin
    )

if (LINUX)
    # In order to support using ld.gold on linux, we need to explicitely
    # specify all libraries that llplugin uses.
  if (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_library(Threads::Threads INTERFACE IMPORTED)
    set_property(TARGET Threads::Threads PROPERTY INTERFACE_LINK_LIBRARIES pthread)
  else()
    set(CMAKE_THREAD_PREFER_PTHREAD TRUE)
    set(THREADS_PREFER_PTHREAD_FLAG TRUE)
    find_package(Threads REQUIRED)
  endif()
    set(LLPLUGIN_LIBRARIES llplugin Threads::Threads)
else (LINUX)
    set(LLPLUGIN_LIBRARIES llplugin)
endif (LINUX)
