#!/bin/bash
# github actions helper for compiling specific prebuilts inline
# -- humbletim 2022.03.27

set -eu
. .github/3p/_assert_defined.sh

assert_defined AUTOBUILD_INSTALLABLE_CACHE AUTOBUILD_CONFIG_FILE \
  INLINE_FS3P_GITURL INLINE_FS3P_DEPS \
  ALTERNATE_FS3P_DEPS

for x in $INLINE_FS3P_DEPS ; do
  echo "[[ $x ]]"
  time .github/3p/inline-build.sh 3p-inline $INLINE_FS3P_GITURL/3p-$x
  echo
done

for x in $ALTERNATE_FS3P_DEPS ; do
  echo "[[ $x ]]"
  time .github/3p/use-alternate.sh $x
  echo
done

# changes to autobuild.xml from autobuild tooling "randomly" reorder entries
# create a sorted hash+url list to use for change detection and cache keys 
(
  echo "import json; print(json.dumps((" ; autobuild installables print ; echo "), indent=4))"
) | python | jq -r ".[]|(.platforms.windows64//.platforms.common)|select(.)|.archive.hash+\"\t\"+.archive.url" \
  | sort -u | tee autobuild.xml.sorted.txt >&2

echo -n "// " >&2
md5sum autobuild.xml.sorted.txt >&2
