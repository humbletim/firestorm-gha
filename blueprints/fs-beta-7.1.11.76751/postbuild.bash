#!/bin/bash

set -Euo pipefail

source $ghash/gha.upload-artifact.bash

snapshot_dir=$build_dir/${version_full}-snapshot
mkdir -pv $snapshot_dir

cpsync() { cp -lunrp "$@" ; }

echo "SNAPSHOT EMERGED OBJECT FILES..." >&2
mkdir -pv $snapshot_dir/objs
build_dir_rel=$(realpath --relative-to="$(pwd -W)" $build_dir || echo $build_dir)
(
    (
        # echo ~+/llwebrtc/llwebrtc.lib
        # grep -vE '/(llwebrtc|media_plugins|slplugin)/
        for x in `ls -1d $build_dir_rel/{ll*,newview,viewer_components/login}/CMakeFiles/ | grep -v /llwebrtc/`; do
            y=$(basename $(dirname "$x"))
            objs=$(find $x -name \*.c*.obj)
            test -z "$objs" || {
                mkdir -pv $snapshot_dir/objs/$y/
                cpsync $objs $snapshot_dir/objs/$y/
            }
        done
        cpsync $build_dir_rel/llwebrtc/llwebrtc.lib $snapshot_dir/objs/
    )
     # > $snapshot_dir/metadata/all.objs.rsp
    # time (
    #     tar -cf - -T $snapshot_dir/metadata/all.objs.rsp --show-transformed-names \
    #         --transform "s|^${PWD#/}/||" \
    #         --transform 's|^([^/]+)/.*[.]dir|\1|x' \
    #          2>$snapshot_dir/metadata/objs.tar.rsp \
    #     | tar -xf - -C$snapshot_dir/objs # xz -T0 - -c > snapshot/objs.tar.xz
    # )
)

echo "SNAPSHOT METADATA..." >&2
mkdir -pv $snapshot_dir/metadata
cp -ua env.d $snapshot_dir/metadata
test ! -s fstuple.json || cp -av fstuple.json $snapshot_dir/metadata/
cp -ua $build_dir/packages-info.json $snapshot_dir/metadata/
cp -ua $nunja_dir/viewer_version.txt $snapshot_dir/metadata/
env | grep INPUT > $snapshot_dir/metadata/INPUT.env
env | grep -i version=  > $snapshot_dir/metadata/version.env

echo "SNAPSHOT PACKAGES..." >&2
mkdir -pv $snapshot_dir/3p/lib
for x in `ls -1 $packages_dir/lib/release | grep -v webrtc` ; do
    cpsync $packages_dir/lib/release/$x $snapshot_dir/3p/lib/
done
mkdir -pv $snapshot_dir/3p/include
for x in `ls -1 $packages_dir/include| grep -v webrtc` ; do
    cpsync $packages_dir/include/$x $snapshot_dir/3p/include/
done
# cpsync $packages_dir/lib/release $snapshot_dir/3p/lib/
# cpsync $packages_dir/include $snapshot_dir/3p/include/
# rm -rf $snapshot_dir/3p/include/webrtc $snapshot_dir/3p/lib/*webrtc*
# ln $source_dir $snapshot_dir/source

echo "SNAPSHOT CORRESPONDING SOURCE..." >&2
mkdir -pv $snapshot_dir/source
cp -ua $build_dir/newview/fsversionvalues.h $snapshot_dir/source/
(
    cd $source_dir
    find ~+ -name \*.cpp -o -name \*.inl -o -name \*.h > $snapshot_dir/metadata/all.includes.txt
    time (
        tar -cf - -T $snapshot_dir/metadata/all.includes.txt --show-transformed-names \
        --transform "s|^${PWD#/}/||" \
         2>$snapshot_dir/metadata/includes.tar.rsp \
         | tar -xf - -C$snapshot_dir/source #xz -T0 - -c > $snapshot_dir/includes.tar.xz
    )
    cd ..
)

(
    cd $snapshot_dir
    ls source/* -1d | sed 's@^@-I${snapshot_dir}/@' > $snapshot_dir/llincludes.rsp.in
    find objs/ -name \*.obj | sed 's@^@${snapshot_dir}/@' > $snapshot_dir/llobjs.rsp.in || exit 77
    cd ..
)

echo "[7z] GENERATING ${version_full}-snapshot.zip..." >&2
cd $build_dir
time 7z -mx5 -bd -bt -tzip a ${version_full}-snapshot.zip ${version_full}-snapshot/

echo "UPLOADING ARTIFACT...${GITHUB_ACTIONS}" >&2
gha-have-runtime || { echo "gha runtime unavailable" && exit 0 ; }
 
grep gha-patch-upload-artifact /d/a/_actions/actions/upload-artifact/v4/dist/upload/index.js || gha-patch-upload-artifact
zipUploadStream=${version_full}-snapshot.zip gha-upload-artifact-fast ${version_full}-snapshot ${version_full}-snapshot.zip

# UPLOAD SNAPSHOT

# cd $snapshot_dir
# gha-upload-artifact-fast ${version_full}-snapshot .
