#!/bin/bash

set -Euo pipefail

source $ghash/gha.upload-artifact.bash

HERE=$(pwd -W 2>/dev/null || pwd)

base=${base:-fs-open}
config_name=${config_name:-Release}
build_dir=${build_dir:-build-vc170-64}
packages_dir=${packages_dir:-$build_dir/packages}
source_dir=${source_dir:-indra}
snapshot_dir=${snapshot_dir:-$base}

mkdir -pv $snapshot_dir

function git_kv_sha() {
    function _git_sha() {
      local path="$1"
      [[ "$path" =~ /[.]git ]] && path="$(dirname "$path")"
      test -e "$path" || { echo _err $? "could not determine .git root from $1" >&2 ; return 19; }
      git -C "$path" describe --always --first-parent --abbrev=7 || { echo _err $? "could not describe '$path'" >&2 ; return 20; }
    }
    for kv in $* ; do
      local k=${kv/=*/} v=${kv/*=/}
      echo $k=`_git_sha $v`
    done
}

(
    echo upstream_rel=$(git -C $source_dir rev-list --count HEAD)
    git_kv_sha version_viewer_sha=$source_dir
    git_kv_sha version_fsvr_sha=$HERE
    echo base=$base
    echo config_name=$config_name
    echo build_dir=$build_dir
    echo packages_dir=$packages_dir
    echo source_dir=$source_dir
    echo snapshot_dir=$snapshot_dir
) | tee $snapshot_dir/ReleaseFS_open.env >&2

source $snapshot_dir/ReleaseFS_open.env

snapshot_dir_abs=$(readlink -f $snapshot_dir)

cpsync() { cp -lunrp "$@" ; }


###########################################################################
###########################################################################
echo "SNAPSHOT EMERGED OBJECT FILES..." >&2
mkdir -pv "$snapshot_dir/objs"

# DEFINITION: Where is the source code relative to the build dir?
# Based on standard SL viewer layout, it's usually parallel or up one level.
# Adjust source_dir if your layout differs (e.g. $ghash/indra or ../indra)

if [ ! -d "$source_dir" ]; then
    echo "CRITICAL: Source root '$source_dir' not found. Cannot perform 1:1 mapping." >&2
    exit 1
fi

# 1. BUILD THE SOURCE MAP (The Source of Truth)
# We use an associative array to map "basename" -> "relative_path_from_root"
# Entry format: [llapp]="newview/llapp.cpp"
declare -A SOURCE_MAP

echo "Indexing source tree for 1:1 reconstruction..." >&2
# Find source units. We include .cpp, .c, .glsl, etc if they compile to objs.
# We exclude 'test' directories if you don't want unit test objs.
while read -r rel_path; do
    # src_file = "../indra/newview/llapp.cpp"
    
    # Clean path relative to source_dir for the 'devtime' structure
    # e.g. "newview/llapp.cpp"
    # rel_path=$(realpath --relative-to="$source_dir" "$src_file")
    
    # Key = "llapp" (no extension)
    filename=$(basename "$rel_path")
    key="${filename%.*}"
    
    SOURCE_MAP["$key"]="$rel_path"

done < <(cd "$source_dir" && find . -type f \( -name "*.cpp" -o -name "*.c" \) | grep -v "/test/")

# 2. HARVEST AND RESTORE OBJECTS
# We ignore the folder they sit in (firestorm-bin.dir, etc). We only care about the file content.
find "$build_dir" -name "*.obj" | while read -r obj_path; do
    
    obj_name=$(basename "$obj_path")   # llapp.obj
    base_name="${obj_name%.*}"         # llapp
    
    # 3. CONSULT THE MAP
    if [ -n "${SOURCE_MAP[$base_name]+x}" ]; then
        # We found a corresponding source file!
        src_rel_path="${SOURCE_MAP[$base_name]}"  # e.g. "newview/llapp.cpp"
        src_dir=$(dirname "$src_rel_path")        # e.g. "newview"
        
        # 4. EXECUTE THE 1:1 RESTORATION
        # Dest: objs/newview/llapp.cpp.obj
        dest_dir="$snapshot_dir/objs/$src_dir"
        dest_file="$dest_dir/$(basename "$src_rel_path").obj"
        
        mkdir -p "$dest_dir"
        
        # Copy and rename to enforce strictly "SourceFileName.obj" convention
        cp -up "$obj_path" "$dest_file"
    else
        # Optional: Log orphans that don't match known source (generated files, etc.)
        dir_name=$(basename $(dirname "$obj_path"))
        target_name=${dir_name%.dir}
        dest_dir="$snapshot_dir/_orphan"
        mkdir -p "$dest_dir"
        # THE CRITICAL STEP: Rename basename.obj -> basename.cpp.obj
        base_obj_name=$(basename "$obj_path" .obj)
        dest_file="$dest_dir/${target_name}.${base_obj_name}.cpp.obj"
        # Copy with update (-u) and preserve attributes (-p)
        echo "[ORPHAN] '$obj_path' '$dest_file'" >&2
        cp -up "$obj_path" "$dest_file"
    fi
done

build_dir_rel=$(realpath --relative-to="$HERE" $build_dir || echo $build_dir)
cpsync `find $build_dir_rel -name llwebrtc.lib` $snapshot_dir/objs/ || { echo missing llwebrtc.lib >&2 ; exit 61; }
cpsync `find $build_dir_rel -name llphysicsextensions*.lib` $snapshot_dir/objs/ || { echo missing llphysicsextensions*.lib >&2 ; exit 62; } || true
cpsync `find $build_dir_rel -name media_plugin_base.lib` $snapshot_dir/objs/ || { echo missing media_plugin_base.lib >&2 ; exit 63; }

# find "$build_dir" -name "*.lib" | grep "/$config_name/" | while read -r lib_file; do
#     echo cp -up "$lib_file" "$snapshot_dir/objs/"
# done

(
    cd $snapshot_dir
    find objs/ -name \*.obj -o -name \*.res | grep -vE '/(cmake|llwebrtc|slplugin|media_plugins)/' | sed 's@^@${snapshot_dir}/@' > llobjs.rsp.in || exit 77
    cd ..
)

###########################################################################
echo "SNAPSHOT METADATA..." >&2
mkdir -pv $snapshot_dir/metadata
mkdir -pv $snapshot_dir/metadata/tmp

test -s $snapshot_dir/metadata/artifacts.tar.xz || tar -cJvf $snapshot_dir/metadata/artifacts.tar.xz `find $build_dir_rel -type f -name \*.tlog -o -name \*.vcxproj\* -o -name \*.h -o -name \*.txt | grep -v /packages`

# cp -ua env.d $snapshot_dir/metadata
# cp -ua $nunja_dir $snapshot_dir/metadata/tmp
# cp -ua $build_dir/msvc.nunja.env $snapshot_dir/metadata/tmp

# test ! -s fstuple.json || cp -av fstuple.json $snapshot_dir/metadata/
cp -ua $build_dir/newview/packages-info.txt $build_dir/newview/build_info.json $snapshot_dir/metadata/
# cp -ua $nunja_dir/viewer_version.txt $snapshot_dir/metadata/
env | grep INPUT > $snapshot_dir/metadata/tmp/INPUT.env
# env | grep -i version=  > $snapshot_dir/metadata/tmp/version.env
find $build_dir/ -type f > $snapshot_dir/metadata/tmp/build_dir.files

( cat /d/a/_temp/_runner_file_commands/step_summary_*-scrubbed > $snapshot_dir/metadata/summary.md ) || true

python ./tpv-gha-nunja/.github/workflows/ReleaseFS_open.yml.py audit | grep '/D' | sed -e 's@^ \+/D @-D@' | sort -u | tee $snapshot_dir/lldefines.rsp

# ( ninja -C $build_dir -t commands ${viewer_bin}-bin | grep -Eo '(")?[-]D[^ =]+(=[^ ]*)?\1?' | grep -vE '_EXPORTS$' | awk '!seen[$0]++' > $snapshot_dir/lldefines.rsp ) || true
# cp -uav $nunja_dir/*defines.rsp $snapshot_dir/metadata/ 2>/dev/null || true

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

if true; then #[[ $viewer_bin == firestorm ]] ; then
    cp -ua $build_dir/newview/fsversionvalues.h $snapshot_dir/source/ || true
fi
cp -ua $build_dir/newview/viewerRes.rc $snapshot_dir/source/ || true

if true; then #[[ $viewer_bin == secondlife ]] ; then
    cpsync $packages_dir/llphysicsextensions* $snapshot_dir/source || true
fi

(
    cd $source_dir
    find ~+ -name \*.cpp -o -name \*.inl -o -name \*.h -o -name \*.hpp \
        | grep -vE '/tests?/' > $snapshot_dir_abs/metadata/tmp/primary.source.txt
    time (
        tar -cf - -T $snapshot_dir_abs/metadata/tmp/primary.source.txt --show-transformed-names \
        --transform "s|^${PWD#/}/||" \
         2>/dev/null \
         | tar -xf - -C$snapshot_dir_abs/source #xz -T0 - -c > $snapshot_dir/includes.tar.xz
    )
    cd ..
)

for x in `grep -Eo '[^"]+[.](cur|ico)' $build_dir/newview/viewerRes.rc | sort -u ` ; do
    if [[ -f $source_dir/newview/res/$x ]]; then
        echo "$build_dir/newview/viewerRes.rc::$x found in $source_dir/newview/res/ ..." >&2
        cp -unrp $source_dir/newview/res/$x $snapshot_dir/source/newview/res/
    elif [[ -f $build_dir/newview/$x ]]; then
        echo "$build_dir/newview/viewerRes.rc::$x found in $build_dir/newview/ ..." >&2
        cp -unrp $build_dir/newview/$x $snapshot_dir/source/newview/res/
    else
        echo "$build_dir/newview/viewerRes.rc::$x source icon not found..." >&2
    fi
done

mkdir -pv $snapshot_dir/metadata/tmp/icons/
for x in `ls $source_dir/newview/*/*.ico $source_dir/newview/*/*/*.ico` ; do
    cp -vua $x $snapshot_dir/metadata/tmp/icons/$(basename $(dirname $(dirname $x))).$(basename $(dirname $x)).$(basename $x)
done

(
    cd $snapshot_dir
    for x in `ls source/* -1d` ; do
        if [[ -d "$x" ]]; then
            echo "$x" | sed 's@^@-I${snapshot_dir}/@'
        else
            echo "skipping non-directory source/ entry: $x" >&2
        fi
    done
    cd ..
) > $snapshot_dir/llincludes.rsp.in

###########################################################################
# stage installer/runtime

cat "`find $build_dir -name \*_setup_tmp.nsi`" | sed -e "s@^File [^ ]\+[/\\]newview[/\\]Release[/\\]@File @g;s@^File @File ${base}/runtime/@g;" > $snapshot_dir/metadata/tmp/runtime.installer.nsi

mkdir -pv $snapshot_dir/metadata/nsi/
sed 's@"[^"]\+\\newview\\installers\\windows\\@\${snapshot_dir}/metadata/nsi/@g' $snapshot_dir/metadata/tmp/runtime.installer.nsi \
    > $snapshot_dir/metadata/installer.nsi.in
grep -Eo '[^"]+\\newview\\installers\\windows\\[^"]+' $snapshot_dir/metadata/tmp/runtime.installer.nsi | tr '\\' '/' | sort -u | sed -e "s@[^ ]\\+/indra/@${source_dir}/@g;" > $build_dir/nsis.txt
for x in `cat $build_dir/nsis.txt` ; do
    cp -unrp "$x" $snapshot_dir/metadata/nsi/
done

APPLICATION_EXE=`find $build_dir -name Firestorm*.exe` || { echo "!APPLICATION_EXE" >&2 ; exit 209 ; }
test -f "$APPLICATION_EXE" || { echo "!APPLICATION_EXE='$APPLICATION_EXE'" >&2 ; exit 225 ; }

grep -E ^File "$snapshot_dir/metadata/tmp/runtime.installer.nsi" | tr '\\' '/' | sed -e 's@^File @@g' | sort -u | fgrep -v "${APPLICATION_EXE}" > $build_dir/runtime.txt

head -2 $build_dir/runtime.txt
cp -av $build_dir/runtime.txt $snapshot_dir/metadata/tmp/
sed "s@$base/runtime/@\${snapshot_dir}/runtime/@g" $build_dir/runtime.txt > $snapshot_dir/metadata/runtime.rsp.in
sed "s@$base/runtime/@runtime/@g" $build_dir/runtime.txt > $snapshot_dir/metadata/runtime.rsp
head -2 $snapshot_dir/metadata/runtime.rsp.in

###########################################################################
bundle=${base}-${upstream_rel}-${version_viewer_sha}-${version_fsvr_sha}
echo "[7z] GENERATING ${bundle}-(devtime|runtime|snapshot).zip..." >&2

#cd $build_dir

#test ! -d $base/runtime || rm -v $base/runtime
# package ${base:-fs-beta-7.1.12-e}/ => "devtime" capture
time ${_7z:-7z} -mx5 -bd -tzip a ${bundle}-devtime.zip $base -xr!$base/tmp

# stage fs-beta-7.1.12-e/runtime/
if test -x C:\\windows\\system32\\cmd.exe ; then
  cmd //c mklink //j "`echo $base/runtime | tr '/' '\\\\'`" "`echo $build_dir/newview/Release |  tr '/' '\\\\'`"
elif test ! -d $base/runtime ; then 
  pwd >&2
  echo "ln -s -T $HERE/$build_dir/newview/Release $base/runtime" >&2
  ln -s -T $HERE/$build_dir/newview/Release $base/runtime  
fi
time ${_7z:-7z} -mx5 -bd -tzip a ${bundle}-runtime.zip @$build_dir/runtime.txt

# make a copy of devtime and append @precision manifested runtime/ folder (to emerge a combined snapshot)
cp -av ${bundle}-devtime.zip ${bundle}-snapshot.zip
mkdir -pv $base/devtime $base/tmp
( cd $base/tmp ; git clone https://github.com/humbletim/p373r-vrmod --single-branch --branch devtime ; )
rsync -av $base/tmp/p373r-vrmod/experiments/portables/ $base/tmp/p373r-vrmod/experiments/winsdk.in/other/vs-emulate-xwin.bat $base/devtime/
time ${_7z:-7z} -mx5 -bd -tzip a ${bundle}-snapshot.zip @$build_dir/runtime.txt $base/devtime/


test "${_7z:-7z}" == 7z || { echo "NOUPLOAD 7z=${_7z}" >&2 ; exit 141 ; }
echo "UPLOADING ARTIFACTS...${GITHUB_ACTIONS}" >&2
gha-have-runtime || { echo "gha runtime unavailable" && exit 0 ; } 
grep gha-patch-upload-artifact /d/a/_actions/actions/upload-artifact/v4/dist/upload/index.js || gha-patch-upload-artifact

zipUploadStream=${bundle}-devtime.zip gha-upload-artifact-fast ${bundle}-devtime ${bundle}-devtime.zip 7
zipUploadStream=${bundle}-runtime.zip gha-upload-artifact-fast ${bundle}-runtime ${bundle}-runtime.zip 7
zipUploadStream=${bundle}-snapshot.zip gha-upload-artifact-fast ${bundle}-snapshot ${bundle}-snapshot.zip 7

# UPLOAD SNAPSHOT

# cd $snapshot_dir
# gha-upload-artifact-fast ${version_full}-snapshot .
