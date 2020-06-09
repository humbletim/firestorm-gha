include(vcpkg_common_functions)

set(VCPKG_POLICY_EMPTY_PACKAGE enabled)

if(NOT VCPKG_TARGET_ARCHITECTURE STREQUAL "x64" AND NOT VCPKG_TARGET_ARCHITECTURE STREQUAL "x86")
    return()
elseif(CMAKE_HOST_WIN32 AND VCPKG_CMAKE_SYSTEM_NAME AND NOT VCPKG_CMAKE_SYSTEM_NAME STREQUAL "WindowsStore")
    return()
endif()

set(BOOST_VERSION 1.60.0)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO boostorg/build
    REF boost-${BOOST_VERSION}
    SHA512 b7d21bd28682b426c95fa7947fc7ade038370a3c29760336d02bf2fb478d2c18e46b023997b2c481fb858f5be8d5ddbf622055f87e5eb739aa6e0b99d5987e5b
    HEAD_REF master
)

vcpkg_download_distfile(ARCHIVE
    URLS "https://raw.githubusercontent.com/boostorg/boost/boost-${BOOST_VERSION}/LICENSE_1_0.txt"
    FILENAME "boost_LICENSE_1_0.txt"
    SHA512 d6078467835dba8932314c1c1e945569a64b065474d7aced27c9a7acc391d52e9f234138ed9f1aa9cd576f25f12f557e0b733c14891d42c16ecdc4a7bd4d60b8
)

vcpkg_download_distfile(BOOSTCPP_ARCHIVE
    URLS "https://raw.githubusercontent.com/boostorg/boost/boost-${BOOST_VERSION}/boostcpp.jam"
    FILENAME "boost-${BOOST_VERSION}-boostcpp.jam"
    SHA512 b4971fae5e1103e55990dcb33c50d59cf3cac0629e3347ab96a2f088d86509a412bf65f9fc55f95d422710d45a1015c5585227d76c5fe45160586b47f29edc91
)

file(INSTALL ${ARCHIVE} DESTINATION ${CURRENT_PACKAGES_DIR}/share/boost-build-160 RENAME copyright)
file(INSTALL ${BOOSTCPP_ARCHIVE} DESTINATION ${CURRENT_PACKAGES_DIR}/tools/boost-build-160 RENAME boostcpp.jam)

# This fixes the lib path to use desktop libs instead of uwp -- TODO: improve this with better "host" compilation
string(REPLACE "\\store\\;" "\\;" LIB "$ENV{LIB}")
set(ENV{LIB} "${LIB}")

file(COPY
    ${SOURCE_PATH}/
    DESTINATION ${CURRENT_PACKAGES_DIR}/tools/boost-build-160
)

file(READ "${CURRENT_PACKAGES_DIR}/tools/boost-build-160/src/tools/msvc.jam" _contents)
string(REPLACE " /ZW /EHsc " "" _contents "${_contents}")
string(REPLACE "-nologo" "" _contents "${_contents}")
string(REPLACE "/nologo" "" _contents "${_contents}")
string(REPLACE "/Zm800" "" _contents "${_contents}")
string(REPLACE "<define>_WIN32_WINNT=0x0602" "" _contents "${_contents}")
file(WRITE "${CURRENT_PACKAGES_DIR}/tools/boost-build-160/src/tools/msvc.jam" "${_contents}")

message(STATUS "Bootstrapping...")
if(CMAKE_HOST_WIN32)
    vcpkg_execute_required_process(
        COMMAND "${CURRENT_PACKAGES_DIR}/tools/boost-build-160/bootstrap.bat" msvc
        WORKING_DIRECTORY ${CURRENT_PACKAGES_DIR}/tools/boost-build-160
        LOGNAME bootstrap-${TARGET_TRIPLET}
    )
else()
    vcpkg_execute_required_process(
        COMMAND "${CURRENT_PACKAGES_DIR}/tools/boost-build-160/bootstrap.sh"
        WORKING_DIRECTORY ${CURRENT_PACKAGES_DIR}/tools/boost-build-160
        LOGNAME bootstrap-${TARGET_TRIPLET}
    )
endif()
