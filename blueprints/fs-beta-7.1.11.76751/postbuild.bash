#!/bin/bash

source $ghash/gha.upload-artifact.bash

mkdir -pv build/snapshot

test -s build/snapshot/includes.tar.xz || (
    find indra/ -name \*.inl -o -name \*.h > build/snapshot/all.includes.txt
    time (
        tar -cvf - -T build/snapshot/all.includes.txt --show-transformed-names \
            --transform "s|^${PWD#/}/||" \
             2>build/snapshot/includes.tar.rsp \
        | xz -T0 - -c > build/snapshot/includes.tar.xz
    )
)

pushd build/

test -s snapshot/all.objs.rsp || (
    find ~+ -name \*.c*.obj | grep -vE '(firestorm-bin.dir|llwebrtc|media_plugins|slplugin)/' > snapshot/all.objs.rsp
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


cd build/snapshot

gha-upload-artifact-fast ${version_full}-snapshot-dotobjs objs.tar.xz
gha-upload-artifact-fast ${version_full}-snapshot-includes includes.tar.xz
