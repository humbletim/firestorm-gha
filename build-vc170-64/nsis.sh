#!/bin/bash
nsi=$(pwd -W)/build-vc170-64/newview/firestorm_setup_tmp.nsi

grep "openvr_api.dll" $nsi \
  || perl -i.bak  -pe 's@^SetCompressor .*$@SetCompressor zlib@g; s@^(.*?)\b(growl.dll)@$1$2\n$1openvr_api.dll@g' \
     $nsi

diff $nsi.bak $nsi

test -f C:/PROGRA~2/NSIS.old mv -v C:/PROGRA~2/NSIS.old C:/PROGRA~2/NSIS

# makensis.exe /V2 build-vc170-64/newview/firestorm_setup_tmp.nsi

grep -E ^File "$nsi" | sed -e 's@.*newview[/\\]@@' > "$nsi.txt"
head -2 "$nsi.txt"
tail -2 "$nsi.txt"

cd build-vc170-64/newview && 7z -bb1 -bt -t7z a "$nsi.7z" "@$nsi.txt"
