#!/bin/bash
maybe-clone viewer ${hub:-github.com} $repo "$ref"
maybe-clone p373r github.com ${GITHUB_REPOSITORY} P373R_6.6.8
echo "snapshot test" -- skipping > repo/p373r/applied

echo '#include <string>' | tee build/dummy.cpp
mkdir -p build/newview
touch build/newview/secondlife-bin.exe
