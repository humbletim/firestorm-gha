#!/bin/bash
#set -e

nsi=$build_dir/newview/firestorm_setup_tmp.nsi

grep "openvr_api.dll" $nsi \
  || perl -i.bak  -pe 's@^SetCompressor .*$@SetCompressor zlib@g; s@^(.*?)\b(growl.dll)@$1$2\n$1openvr_api.dll@g' \
     $nsi
cp -avu $packages_dir/lib/release/openvr_api.dll $build_dir/newview/

#diff $nsi.bak $nsi

grep -E ^File "$nsi" | sed -e "s@.*newview[/\\\\]@$viewer_channel-$version_full/@g" > $build_dir/installer.txt
echo "$viewer_channel-$version_full/load_with_settings_and_cache_here.bat" >> $build_dir/installer.txt

tail -2 $build_dir/installer.txt

cat $fsvr_dir/util/load_with_settings_and_cache_here.bat | envsubst > $build_dir/newview/

ht-ln $build_dir/newview $build_dir/$viewer_channel-$version_full

function make_installer() {
  PATH=/c/Program\ Files\ \(x86\)/NSIS.old makensis.exe -V3 $build_dir/newview/firestorm_setup_tmp.nsi
  mv -v $build_dir/newview/Phoenix*${viewer_version//./-}*.exe $root_dir/
}
function make_7z() {
  sh -c 'cd $build_dir && 7z -bt -t7z a "$root_dir/$viewer_channel-$version_full.7z" "@$build_dir/installer.txt"'
}

#echo cd $build_dir \&\& echo 7z -bt -t7z a "$root_dir/$viewer_channel-$version_full.7z" "@$build_dir/installer.txt"
#echo cd build-vc170-64 \&\& echo 7z -bt -tzip a "$root_dir/$viewer_channel-$version_full.zip" "@$build_dir/installer.txt"

function files2json(){
  echo { \"$(< $build_dir/installer.txt sed 's/,/":"/g' | paste -s -d, - | sed 's/,/", "/g')\" } |tr '\\' '/' > files.json
}

#cat newview/firestorm_setup_tmp.nsi.txt |tr '\\' '/' | tar -cf - --files-from=- | tar -C dist -tf -
