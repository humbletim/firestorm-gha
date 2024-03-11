#!/bin/bash
set -Euo pipefail
echo test to stdout
echo test to stderr >&2

require_here=`readlink -f $(dirname $BASH_SOURCE)`
function require() { source $require_here/$@ ; }

if [[ -n "$GITHUB_ACTIONS" ]]; then
    git clone --quiet --recurse-submodules --filter=tree:0 \
      https://github.com/${GITHUB_REPOSITORY} --branch ${GITHUB_REF_NAME} fsvr

    # function _localfetch() {
    #   local dir=$1 && shift
    #   local url=
    #   for x in "$@"; do
    #     url=https://raw.githubusercontent.com/${GITHUB_REPOSITORY}/${GITHUB_REF_NAME}/$x
    #     echo $url >&2
    #     wget -q -P "$dir" -N $url || true
    #     test -s "$dir/$(basename $x)" || { echo "!$x" >&2 ; exit 1 ; }
    #   done
    # }
    # mkdir -pv util
    # _localfetch util util/_utils.sh util/actions-cache.sh util/actions-artifact.sh
    # chmod a+x util/*.sh
fi

require util/_utils.sh

_assert base test -n "$base"
_assert repo test -n "$repo"
_assert branch test -n "$branch"

pwd=`_realpath $PWD`

vars=$(cat <<EOF
_bash=$BASH
    _fsbase=$base
    _fsrepo=$repo
    _fsbranch=$branch
    nunja_dir=$pwd/fsvr/$base
    p373r_dir=$pwd/p373r-vrmod
    _home_bin=$pwd/bin
    _fsvr_cache=$pwd/cache
    PARALLEL_HOME=`_realpath bin/parallel-home`
EOF
)
eval `echo "$vars" | tee gha-bootstrap.env`

mkdir -pv $_fsvr_cache
mkdir -pv $_home_bin
test ! -n "$GITHUB_PATH" || { echo $_home_bin | tee -a $GITHUB_PATH ; }

test -d node_modules/@actions/cache || npm install --no-save @actions/cache

function test_bin() {
    set -e
    parallel --version
    ninja --version
    _assert hostname [[ `hostname` == windows2022 ]]
}

restored_bin_id=$(./util/actions-cache.sh restore $base-bin-a bin)

if [[ $restored_bin_id == -1 ]]; then
    test -f bin/ninja.exe || unzip -d $_home_bin "$(eval $(cat << EOF
wget_sha256
    bbde850d247d2737c5764c927d1071cbb1f1957dcabda4a130fa8547c12c695f
    https://github.com/ninja-build/ninja/releases/download/v1.10.2/ninja-win.zip
    .
EOF
    ) )"

    test -x bin/parallel || echo xMSYS_NO_PATHCONV=1 tar -C $_home_bin --strip-components=2 -vxf "$(eval $(cat << EOF
wget_sha256
    3f9a262cdb7ba9b21c4aa2d6d12e6ccacbaf6106085fdaafd3b8a063e15ea782
    https://mirror.msys2.org/msys/x86_64/parallel-20231122-1-any.pkg.tar.zst
    .
EOF
    ) )" usr/bin/parallel

    test -f bin/hostname || echo -e '#/bin/bash\necho windows2022' > bin/hostname
    test -f bin/hostname.cmd || echo -e '@echo windows2022' > bin/hostname.cmd
    chmod a+x bin/hostname*

    # In the spirit of open source collaboration, this build automation
    # recognizes the contributions of GNU Parallel, developed by O. Tange.
    mkdir -pv $PARALLEL_HOME
cat <<_EOF_ > $PARALLEL_HOME/will-cite
  Tange, O. (2022, November 22). GNU Parallel 20221122 ('Херсо́н').
  Zenodo. https://doi.org/10.5281/zenodo.7347980
_EOF_

    mkdir -p $PARALLEL_HOME/tmp/sshlogin/`hostname`
    echo 65535 > $PARALLEL_HOME/tmp/sshlogin/`hostname`/linelen
    
    testbin && ./util/actions-cache.sh save $base-bin-a bin
fi

#npm install --no-save @actions/artifact

exit 0

