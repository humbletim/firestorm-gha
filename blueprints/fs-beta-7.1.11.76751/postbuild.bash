#!/bin/bash

source $ghash/gha.upload-artifact.bash

snapshot_dir=$build_dir/${version_full}-snapshot
mkdir -pv $snapshot_dir

# SNAPSHOT METADATA
mkdir -pv $snapshot_dir/metadata
cp -a env.d $snapshot_dir/metadata
cp -av fstuple.json $snapshot_dir/metadata/
cp -av $build_dir/packages-info.json $snapshot_dir/metadata/
cp -av $nunja_dir/viewer_version.txt $snapshot_dir/metadata/
env | grep INPUT > $snapshot_dir/metadata/INPUT.env
env | grep -i version=  > $snapshot_dir/metadata/version.env

# SNAPSHOT PACKAGES
mkdir -pv $snapshot_dir/3p
cp -a $packages_dir/lib/release $snapshot_dir/3p/lib/
cp -a $packages_dir/include $snapshot_dir/3p/include/
rm -rf $snapshot_dir/3p/include/webrtc $snapshot_dir/3p/lib/*webrtc*
# ln $source_dir $snapshot_dir/source

# SNAPSHOT CORRESPONDING SOURCE
mkdir -pv $snapshot_dir/source
(
    pushd repo/viewer/indra
    find ~+ -name \*.cpp -o -name \*.inl -o -name \*.h > $snapshot_dir/metadata/all.includes.txt
    time (
        tar -cf - -T $snapshot_dir/metadata/all.includes.txt --show-transformed-names \
        --transform "s|^${PWD#/}/||" \
         2>$snapshot_dir/metadata/includes.tar.rsp \
         | tar -xf - -C$snapshot_dir/source #xz -T0 - -c > $snapshot_dir/includes.tar.xz
    )
    popd
)

# SNAPSHOT EMERGED OBJECT FILES
mkdir -pv $snapshot_dir/objs
(
    pushd $build_dir/
    (
        echo ~+/llwebrtc/llwebrtc.lib
        find ~+ -name \*.c*.obj | grep -vE '(llwebrtc|media_plugins|slplugin)/'
    ) > $snapshot_dir/metadata/all.objs.rsp
    time (
        tar -cf - -T $snapshot_dir/metadata/all.objs.rsp --show-transformed-names \
            --transform "s|^${PWD#/}/||" \
            --transform 's|^([^/]+)/.*[.]dir|\1|x' \
             2>$snapshot_dir/metadata/objs.tar.rsp \
        | tar -xf - -C$snapshot_dir/objs # xz -T0 - -c > snapshot/objs.tar.xz
    )
    popd
)

cd $build_dir
7z -mx5 -bd -bt -tzip a ${version_full}-snapshot.zip ${version_full}-snapshot/
grep gha-patch-upload-artifact /d/a/_actions/actions/upload-artifact/v4/dist/upload/index.js || gha-patch-upload-artifact
echo zipUploadStream=${version_full}-snapshot.zip gha-upload-artifact-fast ${version_full}-snapshot ${version_full}-snapshot.zip

# UPLOAD SNAPSHOT

# cd $snapshot_dir
# gha-upload-artifact-fast ${version_full}-snapshot .
