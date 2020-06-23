# -*- cmake -*-

# The copy_win_libs folder contains file lists and a script used to
# copy dlls, exes and such needed to run the SecondLife from within
# VisualStudio.

include(CMakeCopyIfDifferent)
include(Linking)

###################################################################
# set up platform specific lists of files that need to be copied
###################################################################
if(WINDOWS)
    set(SHARED_LIB_STAGING_DIR_DEBUG            "${SHARED_LIB_STAGING_DIR}/Debug")
    set(SHARED_LIB_STAGING_DIR_RELWITHDEBINFO   "${SHARED_LIB_STAGING_DIR}/RelWithDebInfo")
    set(SHARED_LIB_STAGING_DIR_RELEASE          "${SHARED_LIB_STAGING_DIR}/Release")

    set(openvr_src_dir ${CMAKE_SOURCE_DIR}/../openvr/bin/win64)
    set(openvr_files openvr_api.dll)
    #*******************************
    # VIVOX - *NOTE: no debug version
    set(vivox_lib_dir "${ARCH_PREBUILT_DIRS_RELEASE}")
    set(slvoice_src_dir "${ARCH_PREBUILT_BIN_RELEASE}")    
    set(slvoice_files SLVoice.exe )
    if (ADDRESS_SIZE EQUAL 64)
        list(APPEND vivox_libs
            vivoxsdk_x64.dll
            ortp_x64.dll
            )
    else (ADDRESS_SIZE EQUAL 64)
        list(APPEND vivox_libs
            vivoxsdk.dll
            ortp.dll
            )
    endif (ADDRESS_SIZE EQUAL 64)

    #*******************************
    # Misc shared libs 

    if (NOT VCPKG_TOOLCHAIN)
    set(release_src_dir "${ARCH_PREBUILT_DIRS_RELEASE}")
    set(release_files
        openjpeg.dll
        libapr-1.dll
        libaprutil-1.dll
        libapriconv-1.dll
        ssleay32.dll
        libeay32.dll
        nghttp2.dll
        glod.dll
        libhunspell.dll
        )
    else()
      set(release_src_dir "${ARCH_PREBUILT_DIRS_RELEASE}")
      set(release_files
          openjpeg.dll
          glod.dll
      )
    endif()

    # Filenames are different for 32/64 bit BugSplat file and we don't
    # have any control over them so need to branch.
    if (BUGSPLAT_DB)
      if(ADDRESS_SIZE EQUAL 32)
        set(release_files ${release_files} BugSplat.dll)
        set(release_files ${release_files} BugSplatRc.dll)
        set(release_files ${release_files} BsSndRpt.exe)
      else(ADDRESS_SIZE EQUAL 32)
        set(release_files ${release_files} BugSplat64.dll)
        set(release_files ${release_files} BugSplatRc64.dll)
        set(release_files ${release_files} BsSndRpt64.exe)
      endif(ADDRESS_SIZE EQUAL 32)
    endif (BUGSPLAT_DB)

    set(release_files ${release_files} growl++.dll growl.dll )
    if (FMODSTUDIO)
      set(debug_files ${debug_files} fmodL.dll)
      set(release_files ${release_files} fmod.dll)
    endif (FMODSTUDIO)

    if (FMODEX)
        if(ADDRESS_SIZE EQUAL 32)
            set(release_files ${release_files} fmodex.dll)
        else(ADDRESS_SIZE EQUAL 32)
            set(release_files ${release_files} fmodex64.dll)
        endif(ADDRESS_SIZE EQUAL 32)
    endif (FMODEX)

    if (OPENAL)
        set(release_files ${release_files} OpenAL32.dll alut.dll)
    endif (OPENAL)

    #*******************************
    # Copy MS C runtime dlls, required for packaging.
    # *TODO - Adapt this to support VC9
    if (MSVC80)
        list(APPEND LMSVC_VER 80)
        list(APPEND LMSVC_VERDOT 8.0)
    elseif (MSVC_VERSION EQUAL 1600) # VisualStudio 2010
        MESSAGE(STATUS "MSVC_VERSION ${MSVC_VERSION}")
    elseif (MSVC_VERSION EQUAL 1800) # VisualStudio 2013, which is (sigh) VS 12
        list(APPEND LMSVC_VER 120)
        list(APPEND LMSVC_VERDOT 12.0)
    elseif (MSVC_VERSION GREATER 1919) # VS2019
        list(APPEND LMSVC_VER 141)
        list(APPEND LMSVC_VERDOT 16.0)
    elseif (MSVC_VERSION GREATER 1909) # VS2017
        list(APPEND LMSVC_VER 141)
        list(APPEND LMSVC_VERDOT 15.0)
    elseif (MSVC_VERSION GREATER 1899) # VS2015
        list(APPEND LMSVC_VER 140)
        list(APPEND LMSVC_VERDOT 14.0)
    else (MSVC80)
        MESSAGE(WARNING "New MSVC_VERSION ${MSVC_VERSION} of MSVC: adapt Copy3rdPartyLibs.cmake")
    endif (MSVC80)

    # try to copy VS2010 redist independently of system version
    # maint-7360 CP
    # list(APPEND LMSVC_VER 100)
    # list(APPEND LMSVC_VERDOT 10.0)

  if (VCPKG_TOOLCHAIN)
        file(TO_CMAKE_PATH "$ENV{VCToolsRedistDir}x64\\Microsoft.VC142.CRT" VC142CRT_PATH)
        message(STATUS "VC142CRT_PATH=${VC142CRT_PATH}")
        copy_if_different(
            ${VC142CRT_PATH}
            "${SHARED_LIB_STAGING_DIR_RELEASE}"
            out_targets
            "msvcp140.dll" "vcruntime140.dll" "vcruntime140_1.dll" "concrt140.dll"
        )
        set(third_party_targets ${third_party_targets} ${out_targets})
        message(STATUS "//VC142CRT ${out_targets}")
  else()
    list(LENGTH LMSVC_VER count)
    math(EXPR count "${count}-1")
    foreach(i RANGE ${count})
        list(GET LMSVC_VER ${i} MSVC_VER)
        list(GET LMSVC_VERDOT ${i} MSVC_VERDOT)
        FIND_PATH(debug_msvc_redist_path NAME msvcr${MSVC_VER}d.dll
            PATHS            
            [HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\VisualStudio\\${MSVC_VERDOT}\\Setup\\VC;ProductDir]/redist/Debug_NonRedist/x86/Microsoft.VC${MSVC_VER}.DebugCRT
            [HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Windows;Directory]/SysWOW64
            [HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Windows;Directory]/System32
            ${MSVC_DEBUG_REDIST_PATH}
            NO_DEFAULT_PATH
            )

        if(EXISTS ${debug_msvc_redist_path})
            set(debug_msvc_files
                msvcr${MSVC_VER}d.dll
                msvcp${MSVC_VER}d.dll
                )

            copy_if_different(
                ${debug_msvc_redist_path}
                "${SHARED_LIB_STAGING_DIR_DEBUG}"
                out_targets
                ${debug_msvc_files}
                )
            set(third_party_targets ${third_party_targets} ${out_targets})

            unset(debug_msvc_redist_path CACHE)
        endif()

        if(ADDRESS_SIZE EQUAL 32)
            # this folder contains the 32bit DLLs.. (yes really!)
            set(registry_find_path "[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Windows;Directory]/SysWOW64")
        else(ADDRESS_SIZE EQUAL 32)
            # this folder contains the 64bit DLLs.. (yes really!)
            set(registry_find_path "[HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\Control\\Windows;Directory]/System32")
        endif(ADDRESS_SIZE EQUAL 32)

        FIND_PATH(release_msvc_redist_path NAME msvcr${MSVC_VER}.dll
            PATHS            
            ${registry_find_path}
            NO_DEFAULT_PATH
            )

        if(EXISTS ${release_msvc_redist_path})
            set(release_msvc_files
                msvcr${MSVC_VER}.dll
                msvcp${MSVC_VER}.dll
                )

            copy_if_different(
                ${release_msvc_redist_path}
                "${SHARED_LIB_STAGING_DIR_RELEASE}"
                out_targets
                ${release_msvc_files}
                )
            set(third_party_targets ${third_party_targets} ${out_targets})

            copy_if_different(
                ${release_msvc_redist_path}
                "${SHARED_LIB_STAGING_DIR_RELWITHDEBINFO}"
                out_targets
                ${release_msvc_files}
                )
            set(third_party_targets ${third_party_targets} ${out_targets})
            message(STATUS "//${MSVC_VER} ${out_targets}")

            unset(release_msvc_redist_path CACHE)
        else()
            MESSAGE(STATUS "WARNING: could not find msvcr${MSVC_VER}.dll in release_msvc_redist_path: ${release_msvc_redist_path}")
        endif()
    endforeach()
  endif()
elseif(DARWIN)
    set(SHARED_LIB_STAGING_DIR_DEBUG            "${SHARED_LIB_STAGING_DIR}/Debug/Resources")
    set(SHARED_LIB_STAGING_DIR_RELWITHDEBINFO   "${SHARED_LIB_STAGING_DIR}/RelWithDebInfo/Resources")
    set(SHARED_LIB_STAGING_DIR_RELEASE          "${SHARED_LIB_STAGING_DIR}/Release/Resources")

    set(vivox_lib_dir "${ARCH_PREBUILT_DIRS_RELEASE}")
    set(slvoice_files SLVoice)
    set(vivox_libs
        libortp.dylib
        libvivoxsdk.dylib
       )
    set(debug_src_dir "${ARCH_PREBUILT_DIRS_DEBUG}")
    set(debug_files
       )
    set(release_src_dir "${ARCH_PREBUILT_DIRS_RELEASE}")
    set(release_files
        libapr-1.0.dylib
        libapr-1.dylib
        libaprutil-1.0.dylib
        libaprutil-1.dylib
        libexception_handler.dylib
        ${EXPAT_COPY}
        libGLOD.dylib
        libndofdev.dylib
        libnghttp2.dylib
        libnghttp2.14.dylib
        libnghttp2.14.14.0.dylib
        libgrowl.dylib
        libgrowl++.dylib
       )

    if (FMODSTUDIO)
      set(debug_files ${debug_files} libfmodL.dylib)
      set(release_files ${release_files} libfmod.dylib)
    endif (FMODSTUDIO)

    if (FMODEX)
      set(debug_files ${debug_files} libfmodexL.dylib)
      set(release_files ${release_files} libfmodex.dylib)
    endif (FMODEX)

elseif(LINUX)
    # linux is weird, multiple side by side configurations aren't supported
    # and we don't seem to have any debug shared libs built yet anyways...
    set(SHARED_LIB_STAGING_DIR_DEBUG            "${SHARED_LIB_STAGING_DIR}")
    set(SHARED_LIB_STAGING_DIR_RELWITHDEBINFO   "${SHARED_LIB_STAGING_DIR}")
    set(SHARED_LIB_STAGING_DIR_RELEASE          "${SHARED_LIB_STAGING_DIR}")

    set(openvr_src_dir ${CMAKE_SOURCE_DIR}/../openvr/bin/linux64)
    set(openvr_files libopenvr_api.so)

    set(vivox_lib_dir "${ARCH_PREBUILT_DIRS_RELEASE}")
    set(vivox_libs
        libsndfile.so.1
        libortp.so
        libvivoxoal.so.1
        libvivoxsdk.so
        )
    set(slvoice_files SLVoice)

    # *TODO - update this to use LIBS_PREBUILT_DIR and LL_ARCH_DIR variables
    # or ARCH_PREBUILT_DIRS
    set(debug_src_dir "${ARCH_PREBUILT_DIRS_DEBUG}")
    set(debug_files
       )
    # *TODO - update this to use LIBS_PREBUILT_DIR and LL_ARCH_DIR variables
    # or ARCH_PREBUILT_DIRS
    set(release_src_dir "${ARCH_PREBUILT_DIRS_RELEASE}")
    # *FIX - figure out what to do with duplicate libalut.so here -brad
    #<FS:TS> Even if we're doing USESYSTEMLIBS, there are a few libraries we
    # have to deal with
    if (NOT USESYSTEMLIBS)
      set(release_files
        #libapr-1.so.0
        #libaprutil-1.so.0
        libatk-1.0.so
        #libdb-5.1.so
        ${EXPAT_COPY}
        #libfreetype.so.6.6.2
        #libfreetype.so.6
        #libGLOD.so
        libgmodule-2.0.so
        libgobject-2.0.so
        libhunspell-1.3.so.0.0.0
        libopenal.so
        #libopenjpeg.so
        libuuid.so.16
        libuuid.so.16.0.22
        libfontconfig.so.1.8.0
        libfontconfig.so.1
       )
    else (NOT USESYSTEMLIBS)
      set(release_files
        libGLOD.so
       )
    endif (NOT USESYSTEMLIBS)

    if (FMODSTUDIO)
      set(debug_files ${debug_files} "libfmodL.so")
      set(release_files ${release_files} "libfmod.so")
    endif (FMODSTUDIO)

    if (FMODEX)
      if(ADDRESS_SIZE EQUAL 32)
        set(debug_files ${debug_files} "libfmodexL.so")
        set(release_files ${release_files} "libfmodex.so")
      else(ADDRESS_SIZE EQUAL 32)
        set(debug_files ${debug_files} "libfmodexL64.so")
        set(release_files ${release_files} "libfmodex64.so")
      endif(ADDRESS_SIZE EQUAL 32)
    endif (FMODEX)

else(WINDOWS)
    message(STATUS "WARNING: unrecognized platform for staging 3rd party libs, skipping...")
    set(vivox_lib_dir "${CMAKE_SOURCE_DIR}/newview/vivox-runtime/i686-linux")
    set(vivox_libs "")
    # *TODO - update this to use LIBS_PREBUILT_DIR and LL_ARCH_DIR variables
    # or ARCH_PREBUILT_DIRS
    set(debug_src_dir "${CMAKE_SOURCE_DIR}/../libraries/i686-linux/lib/debug")
    set(debug_files "")
    # *TODO - update this to use LIBS_PREBUILT_DIR and LL_ARCH_DIR variables
    # or ARCH_PREBUILT_DIRS
    set(release_src_dir "${CMAKE_SOURCE_DIR}/../libraries/i686-linux/lib/release")
    set(release_files "")

    set(debug_llkdu_src "")
    set(debug_llkdu_dst "")
    set(release_llkdu_src "")
    set(release_llkdu_dst "")
    set(relwithdebinfo_llkdu_dst "")
endif(WINDOWS)


################################################################
# Done building the file lists, now set up the copy commands.
################################################################

copy_if_different(
    ${vivox_lib_dir}
    "${SHARED_LIB_STAGING_DIR_DEBUG}"
    out_targets 
    ${vivox_libs}
    )
set(third_party_targets ${third_party_targets} ${out_targets})

copy_if_different(
    ${slvoice_src_dir}
    "${SHARED_LIB_STAGING_DIR_RELEASE}"
    out_targets
    ${slvoice_files}
    )
copy_if_different(
    ${vivox_lib_dir}
    "${SHARED_LIB_STAGING_DIR_RELEASE}"
    out_targets
    ${vivox_libs}
    )

set(third_party_targets ${third_party_targets} ${out_targets})

copy_if_different(
    ${vivox_lib_dir}
    "${SHARED_LIB_STAGING_DIR_RELWITHDEBINFO}"
    out_targets
    ${vivox_libs}
    )
set(third_party_targets ${third_party_targets} ${out_targets})

copy_if_different(
    ${openvr_src_dir}
    "${SHARED_LIB_STAGING_DIR_RELEASE}"
    out_targets
    ${openvr_files}
    )
set(third_party_targets ${third_party_targets} ${out_targets})

copy_if_different(
    ${release_src_dir}
    "${SHARED_LIB_STAGING_DIR_RELEASE}"
    out_targets
    ${release_files}
    )
set(third_party_targets ${third_party_targets} ${out_targets})

copy_if_different(
    ${release_src_dir}
    "${SHARED_LIB_STAGING_DIR_RELWITHDEBINFO}"
    out_targets
    ${release_files}
    )
set(third_party_targets ${third_party_targets} ${out_targets})

#<FS:TS> We need to do this regardless
#if(NOT USESYSTEMLIBS)
  add_custom_target(
      stage_third_party_libs ALL
      DEPENDS ${third_party_targets}
      )
#endif(NOT USESYSTEMLIBS)
