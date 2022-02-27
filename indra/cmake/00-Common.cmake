# -*- cmake -*-
#
# Compilation options shared by all Second Life components.

#*****************************************************************************
#   It's important to realize that CMake implicitly concatenates
#   CMAKE_CXX_FLAGS with (e.g.) CMAKE_CXX_FLAGS_RELEASE for Release builds. So
#   set switches in CMAKE_CXX_FLAGS that should affect all builds, but in
#   CMAKE_CXX_FLAGS_RELEASE or CMAKE_CXX_FLAGS_RELWITHDEBINFO for switches
#   that should affect only that build variant.
#
#   Also realize that CMAKE_CXX_FLAGS may already be partially populated on
#   entry to this file.
#*****************************************************************************

if(NOT DEFINED ${CMAKE_CURRENT_LIST_FILE}_INCLUDED)
set(${CMAKE_CURRENT_LIST_FILE}_INCLUDED "YES")

include(Variables)

# We go to some trouble to set LL_BUILD to the set of relevant compiler flags.
# <FS:Ansariel> Use the previous version for Windows or the compile command line will be screwed up royally
if (WINDOWS)
  set(CMAKE_CXX_FLAGS_RELEASE "$ENV{LL_BUILD_RELEASE}")
  set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "$ENV{LL_BUILD_RELWITHDEBINFO}")
  set(CMAKE_CXX_FLAGS_DEBUG "$ENV{LL_BUILD_DEBUG}")
else (WINDOWS)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} $ENV{LL_BUILD}")
endif (WINDOWS)
# Given that, all the flags you see added below are flags NOT present in
# https://bitbucket.org/lindenlab/viewer-build-variables/src/tip/variables.
# Before adding new ones here, it's important to ask: can this flag really be
# applied to the viewer only, or should/must it be applied to all 3p libraries
# as well?

# Portable compilation flags.
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DADDRESS_SIZE=${ADDRESS_SIZE}")

# Configure crash reporting
set(RELEASE_CRASH_REPORTING OFF CACHE BOOL "Enable use of crash reporting in release builds")
set(NON_RELEASE_CRASH_REPORTING OFF CACHE BOOL "Enable use of crash reporting in developer builds")

if(RELEASE_CRASH_REPORTING)
  set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -DLL_SEND_CRASH_REPORTS=1")
endif()

if(NON_RELEASE_CRASH_REPORTING)
  set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "${CMAKE_CXX_FLAGS_RELWITHDEBINFO} -DLL_SEND_CRASH_REPORTS=1")
  set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -DLL_SEND_CRASH_REPORTS=1")
endif()  

# Don't bother with a MinSizeRel build.
set(CMAKE_CONFIGURATION_TYPES "RelWithDebInfo;Release;Debug" CACHE STRING
    "Supported build types." FORCE)


# Platform-specific compilation flags.

if (WINDOWS)
  # Don't build DLLs.
  set(BUILD_SHARED_LIBS OFF)

  if( USE_COMPILERCACHE )
    string(REPLACE "/Zi" "/Z7" CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG}")
    string(REPLACE "/Zi" "/Z7" CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG}")
    string(REPLACE "/Zi" "/Z7" CMAKE_C_FLAGS_RELEASE "${CMAKE_C_FLAGS_REELASE}")
    string(REPLACE "/Zi" "/Z7" CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE}")
    string(REPLACE "/Zi" "/Z7" CMAKE_C_FLAGS_RELWITHDEBINFO "${CMAKE_C_FLAGS_RELWITHDEBINFO}")
    string(REPLACE "/Zi" "/Z7" CMAKE_CXX_FLAGS_RELWITHDEBINFO "${CMAKE_CXX_FLAGS_RELWITHDEBINFO}")
  endif()

  # for "backwards compatibility", cmake sneaks in the Zm1000 option which royally
  # screws incredibuild. this hack disables it.
  # for details see: http://connect.microsoft.com/VisualStudio/feedback/details/368107/clxx-fatal-error-c1027-inconsistent-values-for-ym-between-creation-and-use-of-precompiled-headers
  # http://www.ogre3d.org/forums/viewtopic.php?f=2&t=60015
  # http://www.cmake.org/pipermail/cmake/2009-September/032143.html
  string(REPLACE "/Zm1000" " " CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS})

  # Without PreferredToolArchitecture=x64, as of 2020-06-26 the 32-bit
  # compiler on our TeamCity build hosts has started running out of virtual
  # memory for the precompiled header file.
  # CP changed to only append the flag for 32bit builds - on 64bit builds,
  # locally at least, the build output is spammed with 1000s of 'D9002'
  # warnings about this switch being ignored.
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /MP")  
  # <FS:ND> Remove this, it's no option to cl.exe and causes a massive amount of warnings.
  #if( ADDRESS_SIZE EQUAL 32 )
    #set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /p:PreferredToolArchitecture=x64")  
  #endif()
  set(CMAKE_CXX_FLAGS_RELWITHDEBINFO 
      "${CMAKE_CXX_FLAGS_RELWITHDEBINFO} /Zo"
      CACHE STRING "C++ compiler release-with-debug options" FORCE)
  set(CMAKE_CXX_FLAGS_RELEASE
      "${CMAKE_CXX_FLAGS_RELEASE} ${LL_CXX_FLAGS} /Zo"
      CACHE STRING "C++ compiler release options" FORCE)
  # zlib has assembly-language object files incompatible with SAFESEH
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /LARGEADDRESSAWARE /SAFESEH:NO /NODEFAULTLIB:LIBCMT /IGNORE:4099")

  set(CMAKE_CXX_STANDARD_LIBRARIES "")
  set(CMAKE_C_STANDARD_LIBRARIES "")

  add_definitions(
      /DNOMINMAX
#      /DDOM_DYNAMIC            # For shared library colladadom
      )

  # <FS:Ansariel> AVX/AVX2 support
  if (USE_AVX_OPTIMIZATION)
  add_compile_options(
      /GS
      /TP
      /W3
      /c
      /Zc:forScope
      /nologo
      /Oy-
      /Oi
      /Ot
      /arch:AVX
      /fp:fast
      )
  elseif (USE_AVX2_OPTIMIZATION)
  add_compile_options(
      /GS
      /TP
      /W3
      /c
      /Zc:forScope
      /nologo
      /Oy-
      /Oi
      /Ot
      /arch:AVX2
      /fp:fast
      )
  else (USE_AVX_OPTIMIZATION)
  # </FS:Ansariel> AVX/AVX2 support
  add_compile_options(
      /GS
      /TP
      /W3
      /c
      /Zc:forScope
      /nologo
      /Oy-
      /Oi
      /Ot
#      /arch:SSE2
      /fp:fast
      )
  # Nicky: x64 implies SSE2
  if( ADDRESS_SIZE EQUAL 32 )
    add_definitions( /arch:SSE2 )
  endif()
  # <FS:Ansariel> AVX/AVX2 support
  endif (USE_AVX_OPTIMIZATION)
     
  # Are we using the crummy Visual Studio KDU build workaround?
  if (NOT VS_DISABLE_FATAL_WARNINGS)
    add_definitions(/WX)
  endif (NOT VS_DISABLE_FATAL_WARNINGS)
endif (WINDOWS)


if (LINUX)
  set(CMAKE_SKIP_RPATH TRUE)


  if (CMAKE_CXX_COMPILER_VERSION VERSION_GREATER_EQUAL 10.0.0 )
    message( FATAL_ERROR "GCC greater 9.4.0 is not supported. Recompile boost for support of GCC 10.0.0 and up." )
  endif()

  # <FS:ND/>
  # And another hack for FORTIFY_SOURCE. Some distributions (for example Gentoo) define FORTIFY_SOURCE by default.
  # Check if this is the case, if yes, do not define it again.
  execute_process(
      COMMAND echo "int main( char **a, int c ){ \n#ifdef _FORTIFY_SOURCE\n#error FORTITY_SOURCE_SET\n#else\nreturn 0;\n#endif\n}" 
      COMMAND sh -c "${CMAKE_CXX_COMPILER} ${CMAKE_CXX_COMPILER_ARG1} -xc++ -w - -o /dev/null"
      OUTPUT_VARIABLE FORTIFY_SOURCE_OUT
	  ERROR_VARIABLE FORTIFY_SOURCE_ERR
	  RESULT_VARIABLE FORTIFY_SOURCE_RES
     )


  if ( ${FORTIFY_SOURCE_RES} EQUAL 0 )
   add_definitions(-D_FORTIFY_SOURCE=2)
  endif()

  # gcc 4.3 and above don't like the LL boost and also
  # cause warnings due to our use of deprecated headers

  add_definitions(
      -D_REENTRANT
      )
  add_compile_options(
      -fexceptions
      -fno-math-errno
      -fno-strict-aliasing
      -fsigned-char
      -msse2
      -mfpmath=sse
      -pthread
      )

  # force this platform to accept TOS via external browser <FS:ND> No, do not.
  # add_definitions(-DEXTERNAL_TOS)

  add_definitions(-DAPPID=secondlife)
  add_compile_options(-fvisibility=hidden)
  # don't catch SIGCHLD in our base application class for the viewer - some of
  # our 3rd party libs may need their *own* SIGCHLD handler to work. Sigh! The
  # viewer doesn't need to catch SIGCHLD anyway.
  add_definitions(-DLL_IGNORE_SIGCHLD)
  if (ADDRESS_SIZE EQUAL 32)
    add_compile_options(-march=pentium4)
  endif (ADDRESS_SIZE EQUAL 32)
  #add_compile_options(-ftree-vectorize) # THIS CRASHES GCC 3.1-3.2
  if (NOT USESYSTEMLIBS)
    # this stops us requiring a really recent glibc at runtime
    add_compile_options(-fno-stack-protector)
    # linking can be very memory-hungry, especially the final viewer link
    #set(CMAKE_CXX_LINK_FLAGS "-Wl,--no-keep-memory")
	set(CMAKE_CXX_LINK_FLAGS "-Wl,--no-keep-memory -Wl,--build-id -Wl,-rpath,'$ORIGIN:$ORIGIN/../lib' -Wl,--exclude-libs,ALL")
	set(CMAKE_EXE_LINKER_FLAGS "-Wl,--no-keep-memory -Wl,--build-id -Wl,-rpath,'$ORIGIN:$ORIGIN/../lib' -Wl,--exclude-libs,ALL")
  endif (NOT USESYSTEMLIBS)

  set(CMAKE_CXX_FLAGS_DEBUG "-fno-inline ${CMAKE_CXX_FLAGS_DEBUG}")

  if( NOT (CMAKE_CXX_COMPILER MATCHES ".*clang") )
	set( CMAKE_CXX_FLAGS "-fabi-version=9 ${CMAKE_CXX_FLAGS}" ) 
  endif()
endif (LINUX)


if (DARWIN)
  # Warnings should be fatal -- thanks, Nicky Perian, for spotting reversed default
  set(CLANG_DISABLE_FATAL_WARNINGS OFF)
  set(CMAKE_CXX_LINK_FLAGS "-Wl,-headerpad_max_install_names,-search_paths_first")
  set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_CXX_LINK_FLAGS}")
  set(DARWIN_extra_cstar_flags "-Wno-unused-local-typedef -Wno-deprecated-declarations")
  #<FS:TS> Silence some more compiler warnings on Xcode 9
  set(DARWIN_extra_cstar_flags "${DARWIN_extra_cstar_flags} -Wno-unused-const-variable -Wno-unused-private-field -Wno-potentially-evaluated-expression")
  # Ensure that CMAKE_CXX_FLAGS has the correct -g debug information format --
  # see Variables.cmake.
  string(REPLACE "-gdwarf-2" "-g${CMAKE_XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT}"
    CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
  # The viewer code base can now be successfully compiled with -std=c++14. But
  # turning that on in the generic viewer-build-variables/variables file would
  # potentially require tweaking each of our ~50 third-party library builds.
  # Until we decide to set -std=c++14 in viewer-build-variables/variables, set
  # it locally here: we want to at least prevent inadvertently reintroducing
  # viewer code that would fail with C++14.
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${DARWIN_extra_cstar_flags} -std=c++14")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS}  ${DARWIN_extra_cstar_flags}")
  # NOTE: it's critical that the optimization flag is put in front.
  # NOTE: it's critical to have both CXX_FLAGS and C_FLAGS covered.
## Really?? On developer machines too?
##set(ENABLE_SIGNING TRUE)
##set(SIGNING_IDENTITY "Developer ID Application:  Phoenix Firestorm Project, Inc., The"")
endif (DARWIN)


if (LINUX OR DARWIN)
  if (CMAKE_CXX_COMPILER MATCHES ".*clang")
    set(CMAKE_COMPILER_IS_CLANGXX 1)
  endif (CMAKE_CXX_COMPILER MATCHES ".*clang")

  if (CMAKE_COMPILER_IS_GNUCXX)
    set(GCC_WARNINGS "-Wall -Wno-sign-compare -Wno-trigraphs")
  elseif (CMAKE_COMPILER_IS_CLANGXX)
    set(GCC_WARNINGS "-Wall -Wno-sign-compare -Wno-trigraphs")
  endif()

  if (NOT GCC_DISABLE_FATAL_WARNINGS)
    set(GCC_WARNINGS "${GCC_WARNINGS} -Werror")
  endif (NOT GCC_DISABLE_FATAL_WARNINGS)

  if (${CMAKE_CXX_COMPILER_ID} STREQUAL "Clang" AND DARWIN AND XCODE_VERSION GREATER 4.9)
    set(GCC_CXX_WARNINGS "$[GCC_WARNINGS] -Wno-reorder -Wno-unused-const-variable -Wno-format-extra-args -Wno-unused-private-field -Wno-unused-function -Wno-tautological-compare -Wno-empty-body -Wno-unused-variable -Wno-unused-value")
  else (${CMAKE_CXX_COMPILER_ID} STREQUAL "Clang" AND DARWIN AND XCODE_VERSION GREATER 4.9)
  #elseif (${CMAKE_CXX_COMPILER_ID} STREQUAL "GNU")
    set(GCC_CXX_WARNINGS "${GCC_WARNINGS} -Wno-reorder -Wno-non-virtual-dtor")
  endif ()

  set(CMAKE_C_FLAGS "${GCC_WARNINGS} ${CMAKE_C_FLAGS}")
  set(CMAKE_CXX_FLAGS "${GCC_CXX_WARNINGS} ${CMAKE_CXX_FLAGS}")

  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -m${ADDRESS_SIZE}")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -m${ADDRESS_SIZE}")
endif (LINUX OR DARWIN)


if (USESYSTEMLIBS)
  add_definitions(-DLL_USESYSTEMLIBS=1)

  if (LINUX AND ADDRESS_SIZE EQUAL 32)
    add_definitions(-march=pentiumpro)
  endif (LINUX AND ADDRESS_SIZE EQUAL 32)

else (USESYSTEMLIBS)
  set(${ARCH}_linux_INCLUDES
      atk-1.0
      cairo
      freetype
      glib-2.0
      gstreamer-0.10
      gtk-2.0
      pango-1.0
      )
endif (USESYSTEMLIBS)

if (NOT GENERATE_DEBUG_SYMBOLS)
  message(WARNING "DISENGAGING DEBUG SYMBOL GENERATION (removing /Z[oiI7]..)")
    #string(REGEX REPLACE "/Z[oiI7]" "" CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG}")
    string(REGEX REPLACE "/Z[oiI7]|/DEBUG" "" CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE}")
    string(REGEX REPLACE "/Z[oiI7]|/DEBUG" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
    string(REGEX REPLACE "/DEBUG(:[A-Z]+)?|/OPT:REF|/FORCE:MULTIPLE " "" CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS}")
    string(REGEX REPLACE "/DEBUG(:[A-Z]+)?|/OPT:REF|/FORCE:MULTIPLE " "" CMAKE_CXX_LINK_FLAGS "${CMAKE_CXX_LINK_FLAGS}")
    string(REGEX REPLACE "/DEBUG(:[A-Z]+)?|/OPT:REF|/FORCE:MULTIPLE " "" CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS}")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /DEBUG:NONE /INCREMENTAL:NO")
    set(CMAKE_CXX_LINK_FLAGS "${CMAKE_CXX_LINK_FLAGS} /DEBUG:NONE /INCREMENTAL:NO")
    set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} /DEBUG:NONE /INCREMENTAL:NO")

    message(STATUS
      "== CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS}\n"
      "== CMAKE_EXE_LINKER_FLAGS ${CMAKE_EXE_LINKER_FLAGS}\n"
      "== CMAKE_CXX_LINKER_FLAGS ${CMAKE_CXX_LINKER_FLAGS}\n"
      "== CMAKE_SHARED_LINKER_FLAGS ${CMAKE_SHARED_LINKER_FLAGS}]\n"
    )
endif()
  
endif(NOT DEFINED ${CMAKE_CURRENT_LIST_FILE}_INCLUDED)
