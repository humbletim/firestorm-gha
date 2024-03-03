#!/bin/bash
#set -e

nsi=$(pwd -W)/build-vc170-64/newview/firestorm_setup_tmp.nsi

grep "openvr_api.dll" $nsi \
  || perl -i.bak  -pe 's@^SetCompressor .*$@SetCompressor zlib@g; s@^(.*?)\b(growl.dll)@$1$2\n$1openvr_api.dll@g' \
     $nsi

cp -avu build-vc170-64/packages/lib/release/openvr_api.dll build-vc170-64/newview

diff $nsi.bak $nsi

test -f C:/PROGRA~2/NSIS.old mv -v C:/PROGRA~2/NSIS.old C:/PROGRA~2/NSIS

# makensis.exe /V2 build-vc170-64/newview/firestorm_setup_tmp.nsi

grep -E ^File "$nsi" | sed -e "s@.*newview[/\\\\]@$viewer_channel-$version_full/@g" > "$nsi.txt"
head -2 "$nsi.txt"
tail -2 "$nsi.txt"

MSYS_NO_PATHCONV=1 cmd.exe /C "cd build-vc170-64 && mklink /J $viewer_channel-$version_full newview"

cd build-vc170-64 && echo 7z -bt -t7z a "$nsi.7z" "@$nsi.txt"
