#!/bin/bash

#maybe-clone p373r github.com ${GITHUB_REPOSITORY} P373R_6.6.8
mkdir -pv repo/p373r
echo $BASH_SOURCE -- skipping > repo/p373r/applied

gha-cache-restore $cache_id-repo-0000 repo/viewer || (
    set -Euo pipefail
    quiet-clone ${hub:-github.com} $repo $ref repo/viewer

    pushd repo/viewer

    git remote add sgeo https://github.com/Sgeo/phoenix-firestorm-alpha
    git fetch sgeo VR_Sgeo_2024
    git -c user.email=CITEST -c user.name=CITEST \
      merge --no-edit sgeo/VR_Sgeo_2024 || exit 6

patch -p1 < <(cat <<'EOF'
diff --git a/indra/newview/llviewerVR.h b/indra/newview/llviewerVR.h
index fd2aa7880..89804262b 100644
--- a/indra/newview/llviewerVR.h
+++ b/indra/newview/llviewerVR.h
@@ -1,7 +1,6 @@
 #pragma once

-#include "../../../openvr/headers/openvr.h"
-#pragma comment(lib, "../../../openvr/lib/win64/openvr_api.lib")
+#include <openvr.h>
 #include "llhudtext.h"
 #include "llgl.h"
 #include "string.h"
EOF
)
  git diff
  # git -C repo/viewer diff
  popd

  gha-cache-save $cache_id-repo-0000 repo/viewer  || exit 37
)
