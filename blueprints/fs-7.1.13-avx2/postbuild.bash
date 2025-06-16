#!/bin/bash

set -Euo pipefail

source $ghash/gha.upload-artifact.bash

snapshot_dir=$build_dir/${base}
mkdir -pv $snapshot_dir

cpsync() { cp -lunrp "$@" ; }

###########################################################################
echo "SNAPSHOT EMERGED OBJECT FILES..." >&2
mkdir -pv $snapshot_dir/objs
build_dir_rel=$(realpath --relative-to="$(pwd -W)" $build_dir || echo $build_dir)
(
    (
        # echo ~+/llwebrtc/llwebrtc.lib
        # grep -vE '/(llwebrtc|media_plugins|slplugin)/
        for x in `ls -1d $build_dir_rel/{ll*,newview,viewer_components/login,newview/llphysicsextensions}/CMakeFiles/ | grep -v /llwebrtc/`; do
            y=$(basename $(dirname "$x"))
            objs=$(find $x -name \*.c*.obj -o -name \*.res)
            test -z "$objs" || {
                mkdir -pv $snapshot_dir/objs/$y/
                cpsync $objs $snapshot_dir/objs/$y/
            }
        done
        cpsync $build_dir_rel/llwebrtc/llwebrtc.lib $snapshot_dir/objs/
        cpsync $build_dir_rel/newview/llphysicsextensions/llphysicsextensionsstub.lib $snapshot_dir/objs/
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

(
    cd $snapshot_dir
    find objs/ -name \*.obj -o -name \*.res | sed 's@^@${snapshot_dir}/@' > $snapshot_dir/llobjs.rsp.in || exit 77
    cd ..
)

###########################################################################
echo "SNAPSHOT METADATA..." >&2
mkdir -pv $snapshot_dir/metadata
mkdir -pv $snapshot_dir/metadata/tmp
cp -ua env.d $snapshot_dir/metadata

cp -ua $nunja_dir $snapshot_dir/metadata/tmp
cp -ua $build_dir/msvc.nunja.env $snapshot_dir/metadata/tmp

test ! -s fstuple.json || cp -av fstuple.json $snapshot_dir/metadata/
cp -ua $build_dir/packages-info.json $snapshot_dir/metadata/
cp -ua $nunja_dir/viewer_version.txt $snapshot_dir/metadata/
env | grep INPUT > $snapshot_dir/metadata/tmp/INPUT.env
env | grep -i version=  > $snapshot_dir/metadata/tmp/version.env
find $build_dir/ -type f > $snapshot_dir/metadata/tmp/build_dir.files

( cat /d/a/_temp/_runner_file_commands/step_summary_*-scrubbed > $snapshot_dir/metadata/summary.md ) || true
( ninja -C $build_dir -t commands ${viewer_bin}-bin | grep -Eo '(")?[-]D[^ =]+(=[^ ]*)?\1?' | grep -vE '_EXPORTS$' | awk '!seen[$0]++' > $snapshot_dir/lldefines.rsp ) || true
cp -uav $nunja_dir/*defines.rsp $snapshot_dir/metadata/ 2>/dev/null || true
###########################################################################
echo "SNAPSHOT PACKAGES..." >&2
mkdir -pv $snapshot_dir/3p/lib
for x in `ls -1 $packages_dir/lib/release | grep -v webrtc` ; do
    cpsync $packages_dir/lib/release/$x $snapshot_dir/3p/lib/
done
mkdir -pv $snapshot_dir/3p/include
for x in `ls -1 $packages_dir/include| grep -v webrtc` ; do
    cpsync $packages_dir/include/$x $snapshot_dir/3p/include/
done
cpsync $build_dir/newview/licenses.txt $snapshot_dir/3p/
cpsync $build_dir/newview/packages-info.txt $snapshot_dir/3p/

###########################################################################
echo "SNAPSHOT CORRESPONDING SOURCE..." >&2
mkdir -pv $snapshot_dir/source
cp -ua $source_dir/../LICENSE $snapshot_dir/

if [[ $viewer_bin == firestorm ]] ; then
    cp -ua $build_dir/newview/fsversionvalues.h $snapshot_dir/source/ || true
fi
cp -ua $build_dir/newview/viewerRes.rc $snapshot_dir/source/ || true

if [[ $viewer_bin == secondlife ]] ; then
    cpsync $packages_dir/llphysicsextensions $snapshot_dir/source
fi

(
    cd $source_dir
    find ~+ -name \*.cpp -o -name \*.inl -o -name \*.h -o -name \*.hpp \
        | grep -vE '/tests?/' > $snapshot_dir/metadata/tmp/primary.source.txt
    time (
        tar -cf - -T $snapshot_dir/metadata/tmp/primary.source.txt --show-transformed-names \
        --transform "s|^${PWD#/}/||" \
         2>/dev/null \
         | tar -xf - -C$snapshot_dir/source #xz -T0 - -c > $snapshot_dir/includes.tar.xz
    )
    cd ..
)

for x in `grep -Eo '[^"]+[.](cur|ico)' $build_dir/newview/viewerRes.rc | sort -u ` ; do
    if [[ -f $source_dir/newview/res/$x ]]; then
        echo "$build_dir/newview/viewerRes.rc::$x found in $source_dir/newview/res/ ..." >&2
        cpsync $source_dir/newview/res/$x $snapshot_dir/source/newview/res/
    elif [[ -f $build_dir/newview/$x ]]; then
        echo "$build_dir/newview/viewerRes.rc::$x found in $build_dir/newview/ ..." >&2
        cpsync $build_dir/newview/$x $snapshot_dir/source/newview/res/
    else
        echo "$build_dir/newview/viewerRes.rc::$x source icon not found..." >&2
    fi
done

mkdir -pv $snapshot_dir/metadata/tmp/icons/
for x in `ls $source_dir/newview/icons/*/*.ico` ; do
    cp -ua $x $snapshot_dir/metadata/tmp/icons/$viewer_bin-$(basename $(dirname $x)).ico
done

(
    cd $snapshot_dir
    for x in `ls source/* -1d` ; do
        if [[ -d "$x" ]]; then
            echo "$x" | sed 's@^@-I${snapshot_dir}/@'
        else
            echo "skipping non-directory source/ entry: $x" >&2
        fi
    cd ..
) > $snapshot_dir/llincludes.rsp.in

###########################################################################
# stage installer/runtime

cp -ua $build_dir/runtime.installer.original.nsi $snapshot_dir/metadata/tmp/

mkdir -pv $snapshot_dir/metadata/nsi/
sed 's@"[^"]\+\\newview\\installers\\windows\\@\${snapshot_dir}/metadata/nsi/@g' $build_dir/runtime.installer.nsi \
    > $snapshot_dir/metadata/installer.nsi.in
grep -Eo '[^"]+\\newview\\installers\\windows\\[^"]+' $build_dir/runtime.installer.nsi | sort -u > $build_dir/nsis.txt
for x in `cat $build_dir/nsis.txt` ; do
    cpsync "$x" $snapshot_dir/metadata/nsi/
done

cp -av $build_dir/APPLICATION_EXE.env $snapshot_dir/metadata/tmp/
. $build_dir/APPLICATION_EXE.env
sed "s@^$viewer_channel-$version_full/@$base/runtime/@g;" $build_dir/installer.txt \
    | grep -vE "${application_bin}|${APPLICATION_EXE}" \
    | tr '\\' '/' > $build_dir/runtime.txt
head -2 $build_dir/runtime.txt
cp -av $build_dir/runtime.txt $snapshot_dir/metadata/tmp/
sed "s@$base/runtime/@\${snapshot_dir}/runtime/@g" $build_dir/runtime.txt > $snapshot_dir/metadata/runtime.rsp.in
sed "s@$base/runtime/@runtime/@g" $build_dir/runtime.txt > $snapshot_dir/metadata/runtime.rsp
head -2 $snapshot_dir/metadata/runtime.rsp.in

###########################################################################
bundle=${base}-${upstream_rel}-${version_shas}
echo "[7z] GENERATING ${bundle}-(devtime|runtime|snapshot).zip..." >&2

cd $build_dir

test ! -d $base/runtime || rm -v $base/runtime
# package ${base:-fs-beta-7.1.12-e}/ => "devtime" capture
time ${_7z:-7z} -mx5 -bd -tzip a ${bundle}-devtime.zip $base

# stage fs-beta-7.1.12-e/runtime/
ht-ln $build_dir/newview $base/runtime
time ${_7z:-7z} -mx5 -bd -tzip a ${bundle}-runtime.zip @$build_dir/runtime.txt

# make a copy of devtime and append @precision manifested runtime/ folder (to emerge a combined snapshot)
cp -av ${bundle}-devtime.zip ${bundle}-snapshot.zip
time ${_7z:-7z} -mx5 -bd -tzip a ${bundle}-snapshot.zip @$build_dir/runtime.txt

test "${_7z:-7z}" == 7z || { echo "NOUPLOAD 7z=${_7z}" >&2 ; exit 141 ; }
echo "UPLOADING ARTIFACTS...${GITHUB_ACTIONS}" >&2
gha-have-runtime || { echo "gha runtime unavailable" && exit 0 ; } 
grep gha-patch-upload-artifact /d/a/_actions/actions/upload-artifact/v4/dist/upload/index.js || gha-patch-upload-artifact

zipUploadStream=${bundle}-devtime.zip gha-upload-artifact-fast ${bundle}-devtime ${bundle}-devtime.zip
zipUploadStream=${bundle}-runtime.zip gha-upload-artifact-fast ${bundle}-runtime ${bundle}-runtime.zip
zipUploadStream=${bundle}-snapshot.zip gha-upload-artifact-fast ${bundle}-snapshot ${bundle}-snapshot.zip

# UPLOAD SNAPSHOT

# cd $snapshot_dir
# gha-upload-artifact-fast ${version_full}-snapshot .
