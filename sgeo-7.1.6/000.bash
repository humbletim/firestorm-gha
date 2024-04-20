#!/bin/bash

#maybe-clone p373r github.com ${GITHUB_REPOSITORY} P373R_6.6.8
mkdir -pv repo/p373r
echo skipping > repo/p373r/applied
maybe-clone viewer ${hub:-github.com} $repo $ref
git -C repo/viewer remote add sgeo https://github.com/Sgeo/phoenix-firestorm-alpha
git -C repo/viewer merge sgeo/VR_Sgeo_2024 || exit 6
