#!/bin/bash
maybe-clone viewer ${hub:-github.com} $repo "$ref"
maybe-clone p373r-vrmod github.com humbletim/p373r-vrmod main

ht-ln repo/p373r-vrmod/community repo/p373r
ht-ln repo/p373r-vrmod/sgeo-minimal/0001-sgeo_min_vr_7.1.9-baseline-diff.patch repo/p373r/0001-sgeo_min_vr_7.1.9-baseline-diff.patch

echo '#include <string>' | tee build/dummy.cpp
mkdir -p build/newview

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
