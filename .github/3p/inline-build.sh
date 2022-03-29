#!/bin/bash
# github actions helper for compiling patched prebuilt deps inline
# -- humbletim 2022.03.27

# usage:
#     .github/3p/inline-build.sh <builddir> <gitrepo[@gitcommit][#pkgname]>
#  or .github/3p/inline-build.sh <builddir> <gitrepo> <gitcommit> [autobuild_package_name]

set -eu
. .github/3p/_assert_defined.sh
. .github/3p/_autobuild_prop_as_json.sh

BUILDDIR=$1
regex='^([^@]+)@([^#]+)#?([-/_a-zA-Z0-9]*)?$'
if [[ "$2" =~ $regex ]] ; then
  REPO=${BASH_REMATCH[1]}
  COMMIT=${BASH_REMATCH[2]}
  NAME=${BASH_REMATCH[3]}
  NAME=${NAME:-${3:-$(basename $REPO)}}
else
  REPO=$2
  COMMIT=${3:-master}
  NAME=${4:-$(basename $REPO)}
fi

srcdir=$BUILDDIR/$NAME
buildcmd=$(dirname $0)/build-cmds/${NAME}.build-cmd.sh
echo
DEBUG=1 assert_defined REPO COMMIT NAME

assert_defined AUTOBUILD_PLATFORM AUTOBUILD_ADDRSIZE AUTOBUILD_VSVER AUTOBUILD_CONFIG_FILE 

function process_results_env() {
  if [[ -f $srcdir/_results.env ]] ; then
    . $srcdir/_results.env
    assert_defined autobuild_package_name autobuild_package_filename autobuild_package_md5
    test -f $autobuild_package_filename || { echo "_results.env references missing autobuild_package_filename=$autobuild_package_filename" ; return 2 ; }

    local before=$(autobuild_prop_as_json $autobuild_package_name .archive)
    test ! -f installables.log || rm -f installables.log
    if [[ "$before" == "null" ]] ; then
      echo -n "=== ADDING NEW PACKAGE $NAME "
      { autobuild installables -a "file:///$autobuild_package_filename" add $autobuild_package_name hash=$autobuild_package_md5 2>&1 ; } >> installables.log \
         || { echo "FAILED TO ADD PACKAGE $NAME"; cat installables.log ; exit 5 ; }
      echo ...done
    else
      echo -n "=== UPDATING PACKAGE $NAME "
      { autobuild installables -a "file:///$autobuild_package_filename" edit $autobuild_package_name hash=$autobuild_package_md5 2>&1 ; } >> installables.log \
      || { echo "FAILED TO UPDATE PACKAGE $NAME"; cat installables.log ; exit 5 ; }
      echo ...done
    fi
    local after=$(autobuild_prop_as_json $autobuild_package_name .archive)
    if [[ "$before" != "$after" ]] ; then
      echo "resulting autobuild.xml entry: $after"
    fi
    return 0
  else
    echo "(skipping preflight process_results_env ($srcdir/_results.env not found))" >&2
    return 1
  fi
}

# check for preexisting _results.env + autobuild archive
# (ie: if populated from github actions cache)
process_results_env && exit 0 || true

test -e $buildcmd || {
    echo "local build-cmd.sh override not found: $buildcmd"
    echo "need to create/adapt a new build-cmd.sh override; see:"
    echo "    git clone $REPO $srcdir"
    exit 2
}

# fetch dependency repo and commit point
test -e $srcdir/.git || (
  git clone -q $REPO $srcdir
  cd $srcdir
  git -c advice.detachedHead=false checkout -f $COMMIT 2>&1
)

# patch build-cmd.sh
cp -av $buildcmd $srcdir/build-cmd.sh
buildjson=$(dirname $0)/build-cmds/${NAME}.autobuild.json
if [[ -f $buildjson && ! -f $srcdir/autobuild.xml ]] ; then
  echo "generating $NAME autobuild.xml from $buildjson" >&2
  jq -r "include \"$(dirname $0)/_autobuild-json2xml\" ; llsd" $buildjson \
    > $srcdir/autobuild.xml
fi

(
    cd $srcdir
    unset AUTOBUILD_CONFIGURATION
    export AUTOBUILD_CONFIG_FILE=$srcdir/autobuild.xml
    export AUTOBUILD_BUILD_ID=$(git rev-parse --short HEAD)
    success=
    test ! -f build.log || rm -vf build.log
    test ! -f package.log || rm -vf package.log
    autobuild install
    echo -n "==== BUILDING $NAME ==== "
    { autobuild build 2>&1 ; } >> build.log || { echo "XXXXX BUILDING $NAME FAILED" ; cat build.log ; exit 3 ; }
    echo "... done"
    echo -n "==== PACKAGING $NAME ==== "
    { autobuild package --results-file _results.env 2>&1 ; } >> package.log || { echo "XXXXX PACKAGING $NAME FAILED" ; cat package.log ; exit 4 ; }
    echo "... done"
)
  
process_results_env
