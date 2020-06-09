# augmented VS2019 + VCPKG + Ninja dependencies
# note: configure_vcpkg_dependency below gets called via use_prebuilt_binary (see Prebuilt.cmake)

# these dependencies rely on a patched vs2019_autobuild.xml for VS2019 compatibility
set(_AUTOBUILD_FALLBACKS dullahan vlc-bin openal nvapi glh_linear glext gntp-growl openjpeg libndofdev ndPhysicsStub xmlrpc-epi tut llca)

if (USE_DISCORD)
  list(APPEND _AUTOBUILD_FALLBACKS discord-rpc)
endif()

# these dependencies come directly from stock vcpkg right now
set(_AUTOBUILD_VCPKGS boost colladadom jpeglib pcre libpng libhunspell libxml2 nghttp2 ogg_vorbis freetype openssl curl google_breakpad apr_suite uriparser zlib jsoncpp expat)

# these dependencies are used via git submodules or special processing
set(_AUTOBUILD_SUBMODULES openvr_api glod)

###################################################################################################
# locate the shortname library under VCPKG installation and configure autolinking against that .lib
function(find_vcpkg_thingie _id _PREFIX)
    find_file(_lib_${_id}
      NAMES "${_id}.lib" "lib${_id}.lib" "${_id}-vc$ENV{AUTOBUILD_VSVER}-mt.lib" "${_id}-vc140-mt.lib"
      PATHS "${_VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/lib"
      NO_DEFAULT_PATH
    )
    if (${_lib_${_id}} STREQUAL _lib_${_id}-NOTFOUND)
        message(FATAL_ERROR "[    VCPKG] [${_target}] ERROR: ${_id} => library not found in '${_VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/lib': ${_id} ${_id}.lib lib${_id}.lib ${_id}-vc$ENV{AUTOBUILD_VSVER}-mt ${_id}-vc140-mt.lib ... ${_lib_${_id}}unmatched GIT SUBMODULE dependency (${_id} / ${_id})")
    endif()
    if (not ${_lib_${id}_logged})
      message(STATUS "[    VCPKG] [${_target}] ${_id} => ${_lib_${_id}}")
      set(${_lib_${id}_logged} ON PARENT_SCOPE)
    endif()
    link_libraries(${_lib_${_id}})
    #_reset_values(${_PREFIX})
endfunction()

###################################################################################################
# given a dependency shortname id (and cmake/Module.cmake prefix for debug logging)
#  ... this attempts to locate and wire-up the vcpkg version
#  FIXME: currently vcpkgs have to be installed manually; need to trigger `vcpkg install ${_id} --triplet x64-windows` etc. here
function(configure_vcpkg_dependency _id _name)
  if(DEBUG_PREBUILT)
    message(STATUS "configure_vcpkg_dependency -- ${_id} ${_name}")
  endif()
  get_filename_component(_target "${PROJECT_SOURCE_DIR}" NAME)
  if (${_id} IN_LIST _AUTOBUILD_SUBMODULES)
    if ("${_id}" STREQUAL "openvr_api")
      if (WINDOWS)
        set(_openvr_plat win64)
      else()
        set(_openvr_plat linux64)
      endif()
      find_file( _openvr_api_lib
        NAMES openvr_api.lib
        PATHS "${CMAKE_BINARY_DIR}/../openvr/lib/${_openvr_plat}"
        NO_DEFAULT_PATH)
        message(STATUS "[SUBMODULE] [${_target}] ${_id} => ${_openvr_api_lib}")
      link_libraries(${_openvr_api_lib})
    elseif ("${_id}" STREQUAL "glod")
      # glod version from alchemy differs; this libifies the vs2013 version instead
      _install_prebuilt_binary(${_id})
      _libify_dll(glod)
      link_libraries( libified_glod.lib )
    else()
      message(FATAL_ERROR "[SUBMODULE] [${_target}] ERROR: ${_id} => unmatched GIT SUBMODULE dependency (${_id} / ${_name})")
    endif()
  elseif (${_id} IN_LIST _AUTOBUILD_VCPKGS)
    if ("${_id}" STREQUAL "boost")
      find_vcpkg_thingie(boost_thread BOOST)
      find_vcpkg_thingie(boost_regex BOOST)
      find_vcpkg_thingie(boost_coroutine-vc140-mt-1_60 BOOST)
      find_vcpkg_thingie(boost_context-vc140-mt-1_60 BOOST)
      find_vcpkg_thingie(boost_system BOOST)
      find_vcpkg_thingie(boost_program_options BOOST)
      find_vcpkg_thingie(boost_wave BOOST)
      find_vcpkg_thingie(boost_filesystem BOOST)
      set(BOOST_FILESYTEM_PATCH_LIBRARY boost_filesystem_patch PARENT_SCOPE)
    elseif ("${_id}" STREQUAL "colladadom")
      find_vcpkg_thingie( collada-dom2.5-dp COLLADA )
    elseif ("${_id}" STREQUAL "jpeglib")
      find_vcpkg_thingie( turbojpeg JPEG )
      find_vcpkg_thingie( jpeg JPEG )
    elseif ("${_id}" STREQUAL "pcre")
      find_vcpkg_thingie( pcre PCRE )
    elseif ("${_id}" STREQUAL "libpng")
      find_vcpkg_thingie( libpng16 PNG )
    elseif ("${_id}" STREQUAL "libhunspell")
      find_vcpkg_thingie(libhunspell HUNSPELL)
      _install_prebuilt_binary(dictionaries)
    elseif ("${_id}" STREQUAL "libxml2")
      find_vcpkg_thingie(libxml2 LIBXML2)
      find_vcpkg_thingie(libiconv LIBICONV)
    elseif ("${_id}" STREQUAL "nghttp2")
      find_vcpkg_thingie(nghttp2 NGHTTP2)
    elseif ("${_id}" STREQUAL "ogg_vorbis")
      find_vcpkg_thingie(ogg OGG)
      find_vcpkg_thingie(vorbis VORBIS)
      find_vcpkg_thingie(vorbisenc VORBISENC)
      find_vcpkg_thingie(vorbisfile VORBISFILE)
    elseif ("${_id}" STREQUAL "freetype")
      find_vcpkg_thingie(freetype FREETYPE)
    elseif ("${_id}" STREQUAL "openssl")
      find_vcpkg_thingie(ssl OPENSSL)
      find_vcpkg_thingie(crypto CRYPTO)
    elseif ("${_id}" STREQUAL "curl")
      find_vcpkg_thingie(curl CURL)
    elseif ("${_id}" STREQUAL "google_breakpad")
      find_vcpkg_thingie(breakpad BREAKPAD)
      find_vcpkg_thingie(breakpad_client BREAKPAD_CLIENT)
    elseif ("${_id}" STREQUAL "apr_suite")
      find_vcpkg_thingie(aprutil-1 APRUTIL)
      find_vcpkg_thingie(apr-1 APR)
    elseif ("${_id}" STREQUAL "uriparser")
       find_vcpkg_thingie(uriparser URIPARSER)
    elseif ("${_id}" STREQUAL "zlib")
       find_vcpkg_thingie(zlib ZLIB)
    elseif ("${_id}" STREQUAL "jsoncpp")
       find_vcpkg_thingie(jsoncpp JSONCPP)
    elseif ("${_id}" STREQUAL "expat") # AND NOT DEFINED ${EXPAT_FOUND})
       find_vcpkg_thingie(expat EXPAT)
    else()
       message(FATAL_ERROR "[    VCPKG] [${_target}] ERROR: ${_id} => unmatched VCPKG dependency (${_id} / ${_name})")
    endif()

  elseif(${_id} IN_LIST _AUTOBUILD_FALLBACKS)
    if (NOT ${_id}_installed EQUAL 0)
      #get_property(tmp_installed GLOBAL PROPERTY ${_id}_installed)
      string(REGEX REPLACE "[^A-Za-z].*$" "" _shortid ${_id})
      file( GLOB _shortid_lic "${CMAKE_BINARY_DIR}/packages/LICENSES/${_shortid}*.txt")
      if (DEBUG_PREBUILT OR NOT EXISTS ${_shortid_lic})
        message(STATUS "[AUTOBUILD] [${_target}] ${_id} => <$ENV{AUTOBUILD_CONFIG_FILE} installable> _shortid=${_shortid} _shortid_lic=${_shortid_lic}")
      endif()
      set(USESYSTEMLIBS_${_id} OFF PARENT_SCOPE) # force Prebuilt to proceed with autobuild install
    endif()
  else()
     message(FATAL_ERROR "[AUTOBUILD] [${_target}] ERROR: unmatched configure_vcpkg_dependency ${_id} ${_name}")
  endif()
endfunction()









#################################################################
#################################################################


    #  # -------------- patch .dll => .lib for VS2019 use -----
    # elseif ("${_id}" STREQUAL "glod")
    #   _install_prebuilt_binary(${_id})
    #   _libify_dll(glod)
    #   link_libraries( libified_glod.lib )
    # elseif ("${_id}" STREQUAL "dullahan")
    #   _install_prebuilt_binary(${_id})
    #   _libify_dll(libcef)
    #   link_libraries( libified_libcef.lib )
    # elseif ("${_id}" STREQUAL "vlc-bin")
    #   _install_prebuilt_binary(${_id})
    #   _libify_dll(libvlc)
    #   _libify_dll(libvlccore)
    #   link_libraries( libified_libvlc.lib libified_libvlccore.lib )

    #  # -------------- fallbacks -----
    # elseif ("${_id}" STREQUAL "nvapi")
    #   _install_prebuilt_binary(${_id})
    #   link_libraries( nvapi.lib )
    # elseif ("${_id}" STREQUAL "openal")
    #   _install_prebuilt_binary(${_id})
    #   link_libraries( OpenAL32.lib alut.lib )
    # elseif ("${_id}" STREQUAL "openjpeg")
    #   link_libraries( ${CMAKE_BINARY_DIR}/openjpeg.lib )
    # elseif ("${_id}" STREQUAL "libndofdev")
    #   link_libraries( libndofdev.lib )
    # elseif ("${_id}" STREQUAL "ndPhysicsStub")
    #   link_libraries( nd_hacdConvexDecomposition.lib hacd.lib nd_Pathing.lib )

#################################################################
macro(_reset_values _ID)
       set(${_ID}_INCLUDE_DIRS "")
       set(${_ID}_INCLUDE_DIR "")
       #set(${_ID}_LIBRARIES "")
       #set(${_ID}_LIBRARY "")
       #set(${_ID}_found OFF)
endmacro()

# include(FindPackageHandleStandardArgs)
# macro(find_vcpkg_library _var _name)
#        find_library(${${_var}} ${_name} REQUIRED PATHS "${_VCPKG_INSTALLED_DIR}/${VCPKG_TARGET_TRIPLET}/lib" NO_DEFAULT_PATH)
# endmacro()

###################################################################################################
# given a DLL prefix, locate it in the packages/{lib,bin}/release folder and extract a VS2019 compatible .lib file
# (allowing majority of stock firestorm VS2013 prebuilt binaries to be used with using VS2019)
function(_libify_dll _name)
  find_file(_dll_${_name}
    NAMES "${_name}.dll" 
    PATHS "${CMAKE_BINARY_DIR}/packages/bin/release" "${CMAKE_BINARY_DIR}/packages/lib/release"
    NO_DEFAULT_PATH)
  if ("${_dll_${_name}}" STREQUAL "" OR "${_dll_${_name}}" MATCHES ".*NOTFOUND")
    message(FATAL_ERROR "dll not found in '${CMAKE_BINARY_DIR}/packages/{bin,lib}/release")
  endif()
  if(DEBUG_PREBUILT)
    message(STATUS COMMAND "cmd /c ${CMAKE_SOURCE_DIR}/scripts/dll2lib.bat 64 ${_dll_${_name}} ${CMAKE_BINARY_DIR}/packages/lib/release/libified_${_name}.lib")
  endif(DEBUG_PREBUILT)
  execute_process(
    COMMAND $ENV{COMSPEC} /c call "${CMAKE_SOURCE_DIR}/../scripts/dll2lib.bat" 64 "${_dll_${_name}}" "${CMAKE_BINARY_DIR}/packages/lib/release/libified_${_name}.lib"
    RESULT_VARIABLE _libified
  )
  message(STATUS "libifiy prebuilt '${_dll_${_name}}' returned ${_libified}")
  if(NOT EXISTS "${CMAKE_BINARY_DIR}/packages/lib/release/libified_${_name}.lib")
    message(FATAL_ERROR "Failed to libifiy prebuilt ${CMAKE_BINARY_DIR}/packages/lib/release/libified_${_name}.lib")
  endif()
endfunction()

