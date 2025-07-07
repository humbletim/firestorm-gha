#!/bin/bash
maybe-clone viewer ${hub:-github.com} $repo "$ref"
#maybe-clone p373r github.com Sgeo/p373r-sgeo-minimal sgeo_min_vr_7.1.9
mkdir -pv repo/p373r
echo $BASH_SOURCE -- skipping > repo/p373r/applied
echo 'https://github.com/Sgeo/p373r-sgeo-minimal/tree/sgeo_min_vr_7.1.9' > repo/p373r/.gha_source

pushd repo/viewer
    git remote add sgeo-minimal https://github.com/Sgeo/p373r-sgeo-minimal
    git fetch sgeo-minimal sgeo_min_vr_7.1.9
    git checkout sgeo-minimal/sgeo_min_vr_7.1.9 -- indra/newview/llviewerVR.\*
    bash $fsvr_dir/util/git_union_merge.bash sgeo-minimal/sgeo_min_vr_7.1.9 indra/newview/llviewerdisplay.cpp
    git status
    # git diff -U0 ...sgeo-minimal/sgeo_min_vr_7.1.9 | patch -p1 --merge
    # git -c user.email=CITEST -c user.name=CITEST merge --no-edit sgeo-minimal/sgeo_min_vr_7.1.9
    # || {
    #   dos2unix --to-stdout $nunja_dir/sgeo-minimal.7.1.10.mergeconflict-fixes.patch | patch -p1
    #   git add -u
    #   git -c user.email=CITEST -c user.name=CITEST commit -m "sgeo-minimal.7.1.10 locally patched"
    # }
    patch -p1 < <(cat <<'EOF'
diff --git a/indra/newview/llviewerVR.h b/indra/newview/llviewerVR.h
index fd2aa7880..89804262b 100644
--- a/indra/newview/llviewerVR.h
+++ b/indra/newview/llviewerVR.h
@@ -1,7 +1,7 @@
 #pragma once

-#include "../../../openvr/headers/openvr.h"
-#pragma comment(lib, "../../../openvr/lib/win64/openvr_api.lib")
+#include <openvr.h>
+#include "glh/glh_linear.h"
 #include "llhudtext.h"
 #include "llgl.h"
 #include "string.h"
EOF
)
  git diff
popd

pushd repo/viewer
  patch -p1 < <(cat <<'EOF'
diff --git a/indra/newview/viewer_manifest.py b/indra/newview/viewer_manifest.py
index 9fa11fd534..2effbae944 100755
--- a/indra/newview/viewer_manifest.py
+++ b/indra/newview/viewer_manifest.py
@@ -1001,7 +1001,7 @@ class Windows_x86_64_Manifest(ViewerManifest):
             OutFile "%(installer_file)s"
             !define INSTNAME   "%(app_name_oneword)s"
             !define SHORTCUT   "%(app_name)s"
-            !define DL_URL   "%(dl_url)s"
+            !define DL_URL   "https://github.com/humbletim/firestorm-gha/wiki/downloads-legacy-cpus#${VERSION_LONG}"
             !define URLNAME   "secondlife"
             !define IS64BIT   "%(is64bit)d"
             !define ISAVX2   "%(isavx2)d"
EOF
)
  git diff
  # git -C repo/viewer diff
popd

echo "triggering tmate session with non-zero exit code"
exit 62