# -*- cmake -*-
include(Prebuilt)

if (NOT USESYSTEMLIBS)
  if (LINUX)
    _install_prebuilt_binary(libuuid)
    _install_prebuilt_binary(fontconfig)
  endif (LINUX)
  #_install_prebuilt_binary(libhunspell)
  _install_prebuilt_binary(slvoice)
#  use_prebuilt_binary(libidn)
endif(NOT USESYSTEMLIBS)
