#!/bin/bash

source $ghash/gha.upload-artifact.bash

mkdir -pv $build_dir/snapshot

test -s $build_dir/snapshot/includes.tar.xz || (
    find indra/ -name \*.inl -o -name \*.h > $build_dir/snapshot/all.includes.txt
    time (
        tar -cvf - -T $build_dir/snapshot/all.includes.txt --show-transformed-names \
            --transform "s|^${PWD#/}/||" \
             2>$build_dir/snapshot/includes.tar.rsp \
        | xz -T0 - -c > $build_dir/snapshot/includes.tar.xz
    )
)

pushd $build_dir/

test -s snapshot/all.objs.rsp || (
    find ~+ -name \*.c*.obj | grep -vE '(llwebrtc|media_plugins|slplugin)/' > snapshot/all.objs.rsp
    echo ~+/llwebrtc/llwebrtc.lib >> snapshot/all.objs.rsp
    # echo ~+/llwebrtc/llwebrtc.dll >> snapshot/all.objs.rsp
)

test -s snapshot/objs.tar.xz || (
    time (
        tar -cvf - -T snapshot/all.objs.rsp --show-transformed-names \
            --transform "s|^${PWD#/}/||" \
            --transform 's|^([^/]+)/.*[.]dir|\1|x' \
             2>snapshot/objs.tar.rsp \
        | xz -T0 - -c > snapshot/objs.tar.xz
    )
)

popd


cp -av $build_dir/packages-info.json $build_dir/snapshot

cd $build_dir && gha-upload-artifact-fast ${version_full}-snapshot snapshot
