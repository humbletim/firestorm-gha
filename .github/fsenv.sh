#!/bin/bash
# github actions helper to initialize environment variables for building firestorm
# -- humbletim 2022.03.27

set -eu

# function wrapper to avoid leaking variables when "sourced" into other scripts
function _fsenv() {

  # setenv <name> [default-value]
  #   exports the named variable and emits a key="value" to stdout
  #   (a no-op when the variable doesn't exist and no default is specified)
  function setenv() {
    if [[ ! ${!1+x} ]] ; then
      if [[ $# -lt 2 ]] ; then return 0 ; fi
      eval "export ${1}=\"$2\""
    fi
    if [[ ${!1} == *$'\n'* ]] ; then
      # bash and github action multiline env vars compat
      echo "${1}<<EOF"
      echo "${!1}"
      echo "EOF"
    else
      echo "${1}=\"${!1}\""
    fi
  }

  setenv _3P_UTILSDIR "$(cd $(dirname $0)/3p && pwd)"

  ############################################################################
  # workaround for github actions receiving 403: Forbidden errors when trying to
  # download prebuilts from 3p.firestormviewer.org

  # 3p-<package_name> deps are resolved relative to this URL
  setenv INLINE_FS3P_GITURL https://vcs.firestormviewer.org/3p-libraries

  # format: packagerepo=gitcommit
  setenv INLINE_FS3P_DEPS "
    discord-rpc=a21e3dc
    ndPhysicsStub=aad4d9e
    freetype=a8975b6
    openjpeg2=d23ab9af
    gntp-growl=7ed68be
    glod=eecf86f
  "

  # TODO: figure out where firestorm source code for 3p-dictionaries lives...
  #       but for now substituting the "official" LL prebuilt seems to work.

  # format: url=md5
  setenv ALTERNATE_FS3P_DEPS "
    http://automated-builds-secondlife-com.s3.amazonaws.com/ct2/55025/511964/dictionaries-1.538984-common-538984.tar.bz2=d778c6a3475bc35ee8b9615dfc38b4a9
  "
  # unused
  # http://automated-builds-secondlife-com.s3.amazonaws.com/ct2/55025/511964/dictionaries-1.538984-common-538984.tar.bz2=d778c6a3475bc35ee8b9615dfc38b4a9
  # https://automated-builds-secondlife-com.s3.amazonaws.com/ct2/78593/744010/freetype-2.4.4.557047-windows64-557047.tar.bz2=69307aaba16ac71531c9c4d930ace993
  # http://automated-builds-secondlife-com.s3.amazonaws.com/ct2/55004/511885/glod-1.0pre3.538980-windows64-538980.tar.bz2=6302ee1903ab419e76565d9eb6acd274
  # http://automated-builds-secondlife-com.s3.amazonaws.com/ct2/54974/511767/openjpeg-1.5.1.538970-windows64-538970.tar.bz2=5b5c80807fa8161f3480be3d89fe9516
  # https://bitbucket.org/kokua/3p-ndPhysicsStub/downloads/ndPhysicsStub-1.0-windows64-203290044.tar.bz2=bd172f8cf47ce5ba53a4d4128b2580d5
  ############################################################################

  ### AUTOBUILD_ environment variables
  if [[ ! ${GITHUB_WORKSPACE+x} ]] ; then
    case `uname -s` in
      MINGW*) local GITHUB_WORKSPACE=$(pwd -W) ;;
      *) local GITHUB_WORKSPACE=$PWD ;;
    esac
  fi
  setenv AUTOBUILD_VARIABLES_FILE ${GITHUB_WORKSPACE}/fs-build-variables/variables
  setenv AUTOBUILD_CONFIG_FILE ${GITHUB_WORKSPACE}/autobuild.xml
  setenv AUTOBUILD_INSTALLABLE_CACHE ${GITHUB_WORKSPACE}/autobuild-cache

  setenv AUTOBUILD_LOGLEVEL --verbose
  setenv AUTOBUILD_PLATFORM windows64
  setenv AUTOBUILD_ADDRSIZE 64
  setenv AUTOBUILD_VSVER 164
  setenv AUTOBUILD_CONFIGURATION ReleaseFS_open
  setenv AUTOBUILD_BUILD_ID 0

  ### environment variables specific to github actions / windows builds
  # setenv VIEWER_CHANNEL=FirestormVR-GHA
  setenv PreferredToolArchitecture x64
  setenv VIEWER_VERSION_REVISION dev
  setenv FSBUILD_DIR build-vc${AUTOBUILD_VSVER}-${AUTOBUILD_ADDRSIZE}
  setenv FSVS_TARGET Ninja # 'Visual Studio 16 2019'

  setenv VIEWER_VERSION_STR `echo $(cat indra/newview/VIEWER_VERSION.txt)`.${AUTOBUILD_BUILD_ID}
  setenv VIEWER_VERSION_GITHASH $(git log -n 1 | grep "Merge " | awk '{ print $2 }' | xargs git rev-parse --short 2>/dev/null || git rev-parse --short HEAD)
  setenv VIEWER_CHANNEL
  unset _fsenv
}
_fsenv
# exec wrapped command line (if any)
if [[ -n $# ]] ; then
  "$@"
fi
