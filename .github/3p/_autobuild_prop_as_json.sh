#!/bin/bash

# example usage:
#  autobuild_prop_as_json "glod" ".archive.url"
function autobuild_prop_as_json() {
  (
    echo 'import json; print(json.dumps(('
    autobuild installables print $1
    echo '), indent=4))'
  ) | python | jq -r "(.platforms.windows64//.platforms.common)|$2"
}

function autobuild_jq() {
  (
    echo 'import json; print(json.dumps(('
    autobuild installables print
    echo '), indent=4))'
  ) | python | jq -r "$@"
}
