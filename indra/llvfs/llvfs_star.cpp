#if _WIN32
#ifndef WIN32
  #define WIN32
#endif
#include <winsock2.h>
#endif
#include "lldir.cpp"
#include "lldiriterator.cpp"
#include "lllfsthread.cpp"
#include "llpidlock.cpp"
#include "llvfile.cpp"
#include "llvfs.cpp"
#include "llvfsthread.cpp"
