#if _WIN32
#ifndef WIN32
  #define WIN32
#endif
#include <winsock2.h>
#endif
#define GLH_EXT_SINGLE_FILE
#include "stdtypes.h"
#include "llglheaders.h"

#include "llcubemap.cpp"
#include "llfontbitmapcache.cpp"
#include "llfontfreetype.cpp"
#include "llfontgl.cpp"
#include "llfontregistry.cpp"
#include "llgl.cpp"
#include "llgldbg.cpp"
#include "llglslshader.cpp"
#include "llgltexture.cpp"
#include "llimagegl.cpp"
#include "llpostprocess.cpp"
#include "llrender.cpp"
#include "llrender2dutils.cpp"
#include "llrendernavprim.cpp"
#include "llrendersphere.cpp"
#include "llrendertarget.cpp"
#include "llshadermgr.cpp"
#include "lltexture.cpp"
#include "lluiimage.cpp"
#include "llvertexbuffer.cpp"
#include "llglcommonfunc.cpp"
