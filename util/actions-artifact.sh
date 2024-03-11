#!/bin/bash

# helper to utilize gha artifact upload as part of bash scripting
# see: https://github.com/actions/toolkit/tree/main/packages/artifacts
# 2024.03.11 humbletim
#
# usage:
#   # optional environment vars: retentionDays=N compressionLevel=N
#   ./actions-artifact.sh upload id-1 ...paths 
#


upload=$(cat <<'EOF'
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
    ).then((x,y) =>console.warn('then', x,y)
    ).catch((e)=>console.error('error', e));
EOF
)

test=$(cat <<'EOF'
    const [_, name, ...files] = process.argv;
    console.warn("argv", name, files);

    const args = {
        name, files,
        rentionDays: +process.env.retentionDays || 1,
        compressionLevel: +process.env.compressionLevel || 0,
        workingDirectory: process.env.workingDirectory || '.',
    };
    console.warn(args);
    process.exit(-1);
EOF
)

set -Euo pipefail
script="${!1}"
shift
exec node -e "${script}" "$@"
exit 0
