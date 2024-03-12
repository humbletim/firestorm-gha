#!/bin/bash

# helper to utilize gha artifact upload as part of bash scripting
# see: https://github.com/actions/toolkit/tree/main/packages/artifacts
# 2024.03.11 humbletim
#
# usage:
#   # optional environment vars: retentionDays=N compressionLevel=N
#   ./actions-artifact.sh upload id-1 ...paths 
#

function actions-artifact-nodeeval() {
    local cmd=$1 script=$2
    shift 2
    echo "node -e {{$cmd}} $@" >&2
    result="$(node -e "${script}" "$@" 2>&1 || echo "${cmd}_error=$?")"
    test -n "$NODE_DEBUG" && echo "$result" >&2 ;
    outvalue=$(echo "$result" | grep -Eo "^${cmd}_(result|error)=(.*)\$" | sed -E 's@^\w+_result=@@')
    echo "$outvalue"
}

function actions-artifact-list() {
local list=$(cat <<'EOF'
    const [_, ownername, id] = process.argv;
    const [ owner, name ] = ownername.split('/');
    console.warn("argv", { owner, name, id });
    const {DefaultArtifactClient} = require('@actions/artifact')
    const artifact = new DefaultArtifactClient()
    artifact.listArtifacts({
      findBy: {
        // must have actions:read permission on target repository
        token: process.env['GITHUB_TOKEN'],
        workflowRunId: id,
        repositoryOwner: owner,
        repositoryName: name,
      }  
    }
    ).then((x,y) =>console.log('list_result='+x)
    ).catch((e)=>console.error('list_error='+e));
EOF
)
  actions-artifact-nodeeval list "${list}" "$@"
}


# ```ts
# await artifact.downloadArtifact(1337, {
#   findBy
# })
# 
# // can also be used in other methods
# 
# await artifact.getArtifact('my-artifact', {
#   findBy
# })
# 

function actions-artifact-upload() {
local upload=$(cat <<'EOF'
    const [_, name, ...files] = process.argv;
    console.warn("argv", name, files);

    const args = {
        name, files,
        rentionDays: +process.env.retentionDays || 1,
        compressionLevel: +process.env.compressionLevel || 0,
        workingDirectory: process.env.workingDirectory || '.',
    };
    console.warn(args);
    const {DefaultArtifactClient} = require('@actions/artifact')
    const artifact = new DefaultArtifactClient()
    artifact.uploadArtifact( 
        args.name, 
        args.files,
        args.workingDirectory,
        { retentionDays: args.retentionDays, compressionLevel: args.compressionLevel}
    ).then((x,y) =>console.log('upload_result='+x)
    ).catch((e)=>console.error('upload_error='+e));
EOF
)
  actions-artifact-nodeeval upload "${upload}" "$@"
}

function actions-artifact-test() {
local test=$(cat <<'EOF'
    const [_, name, ...files] = process.argv;
    console.warn("argv", name, files);

    const args = {
        name, files,
        rentionDays: +process.env.retentionDays || 1,
        compressionLevel: +process.env.compressionLevel || 0,
        workingDirectory: process.env.workingDirectory || '.',
    };
    console.log('test_result='+JSON.stringify(args));
    //process.exit(-1);
EOF
)
  actions-artifact-nodeeval test "${test}" "$@"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  func=$1 && shift
  declare -f actions-artifact-$func &>/dev/null && func=actions-artifact-$func
  $func "$@"
fi
