#!/bin/bash
maybe-clone viewer ${hub:-github.com} $repo "$ref"
maybe-clone p373r github.com ${GITHUB_REPOSITORY} P373R_6.6.8

pushd repo/p373r_dir
  patch -p1 < <(cat <<'EOF'
diff --git a/llviewerVR.h b/llviewerVR.h
index 0d221b2..108e96c 100644
--- a/llviewerVR.h
+++ b/llviewerVR.h
@@ -1,6 +1,7 @@
 #pragma once
 
 #include <openvr.h>
+#include "glh/glh_linear.h"
 #include "llhudtext.h"
 #include "llgl.h"
 #include "string.h"
EOF
)
  git diff
popd

#echo "snapshot test" -- skipping > repo/p373r/applied

echo '#include <string>' | tee build/dummy.cpp
mkdir -p build/newview
#touch build/newview/firestorm-bin.exe

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

