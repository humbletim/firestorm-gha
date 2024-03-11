#!/bin/bash

# helper to utilize gha caching as part of lower-level bash scripting
# see: https://github.com/actions/toolkit/tree/main/packages/cache
# 2024.03.11 humbletim
#
# usage:
#   ./actions-cache.sh save id-1 ...paths 
#   ./util/actions-cache.sh restore id-1 ...paths
#
#   # or space-separated ids for fallback restoreKeys 
#   ./actions-cache-save.sh restore "id-1 id-" ...paths 

restore=$(cat <<'EOF'
    let [ _, key, ...paths ] = process.argv;
    let restoreKeys=[];
    [ key, ...restoreKeys ] = key.split(/\s+/);
    console.log({ key, restoreKeys, paths });
    require('@actions/cache').restoreCache(paths, key, restoreKeys).then((x)=>console.log(x))
    .catch((e)=>{console.error(e);process.exit(2);})
EOF
)

save=$(cat <<'EOF'
    const [ _, key, ...paths ] = process.argv;
    console.log({ key, paths });
    require('@actions/cache').saveCache(paths, key).then((x)=>console.log(x))
    .catch((e)=>{console.error(e);process.exit(2);})
EOF
)

set -Euo pipefail
script="${!1}"
shift
exec node -e "${script}" "$@"
exit 0

############################################
# cat <<'EOF'
#     # offline test (verifies plumbing only)
#     mkdir /tmp/actions-cache-test
#     cd /tmp/actions-cache-test
#     npm i @actions/cache
#     ACTIONS_CACHE_URL=file:///dev/null
#     RUNNER_TEMP=$PWD
#     GITHUB_WORKSPACE=$PWD
#     GITHUB_SERVER_URL=file:///dev/null
#     GITHUB_REF=none
#     ./util/actions-cache.sh save id-1 ...paths 
#     ./util/actions-cache.sh restore id-1 ...paths
# EOF
# 
