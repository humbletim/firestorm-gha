#!/bin/bash

#maybe-clone p373r github.com ${GITHUB_REPOSITORY} P373R_6.6.8
mkdir -pv repo/p373r
echo skipping > repo/p373r/applied
maybe-clone viewer ${hub:-github.com} $repo $ref
git -C repo/viewer remote add sgeo https://github.com/Sgeo/phoenix-firestorm-alpha
git fetch sgeo VR_Sgeo_2024
git -C repo/viewer -c user.email=x -c user.name=y merge --no-commit --no-edit sgeo/VR_Sgeo_2024 || exit 6

cd repo/viewer

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

git -C repo/viewer diff

true
