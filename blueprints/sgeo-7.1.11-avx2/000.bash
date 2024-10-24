#!/bin/bash

quiet-clone github.com Sgeo/p373r-sgeo-minimal sgeo_min_vr_7.1.9 repo/p373r
echo $BASH_SOURCE -- skipping > repo/p373r/applied
echo 'https://github.com/Sgeo/p373r-sgeo-minimal/tree/sgeo_min_vr_7.1.9' > repo/p373r/.gha_source

gha-cache-restore $cache_id-repo-0000 repo/viewer || (
    set -Euo pipefail
    quiet-clone ${hub:-github.com} $repo $ref repo/viewer

    pushd repo/viewer
    
    git remote add sgeo-minimal https://github.com/Sgeo/p373r-sgeo-minimal
    git fetch sgeo-minimal sgeo_min_vr_7.1.9
    git -c user.email=CITEST -c user.name=CITEST merge --no-edit sgeo-minimal/sgeo_min_vr_7.1.9 || {
      dos2unix --to-stdout $nunja_dir/sgeo-minimal.7.1.10.mergeconflict-fixes.patch | patch -p1
      git add -u
      git -c user.email=CITEST -c user.name=CITEST commit -m "sgeo-minimal.7.1.10 locally patched"
    }

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
patch -p1 < <(cat <<'EOF'
diff --git a/indra/newview/installers/windows/installer_template.nsi b/indra/newview/installers/windows/installer_template.nsi
index 29ae1e54f05..53d6ff09826 100644
--- a/indra/newview/installers/windows/installer_template.nsi
+++ b/indra/newview/installers/windows/installer_template.nsi
@@ -244,7 +244,7 @@ Function CheckCPUFlagsAVX2
     ; Replace %DLURL% in the language string with the URL
     ${WordReplace} "$(MissingAVX2)" "%DLURL%" "$2" "+*" $3
     MessageBox MB_OK "$3"    
-    ${OpenURL} '$2'
+    ${OpenURL} "${DL_URL}-legacy-cpus#version-${VERSION_LONG}"
     Quit
 
   OK_AVX2:
@@ -267,7 +267,7 @@ Function CheckCPUFlagsAVX2_Prompt
 
     MessageBox MB_YESNO $3 IDYES DownloadAVX2 IDNO ContinueInstall
     DownloadAVX2:
-      ${OpenURL} '$3'
+      ${OpenURL} "${DL_URL}#version-${VERSION_LONG}"
       Quit
     ContinueInstall:
       Pop $3
diff --git a/indra/newview/viewer_manifest.py b/indra/newview/viewer_manifest.py
index 9fa11fd534c..0dcc76d3ab3 100755
--- a/indra/newview/viewer_manifest.py
+++ b/indra/newview/viewer_manifest.py
@@ -939,6 +939,7 @@ class Windows_x86_64_Manifest(ViewerManifest):
         return result
         # </FS:Ansariel>
     def dl_url_from_channel(self):
+        return "https://github.com/humbletim/firestorm-gha/wiki/downloads"
         if self.channel_type() == 'release':
             return 'https://www.firestormviewer.org/choose-your-platform'
         elif self.channel_type() == 'beta':
EOF
)
  git diff
  # git -C repo/viewer diff
  popd

  gha-cache-save $cache_id-repo-0000 repo/viewer  || exit 37
)
