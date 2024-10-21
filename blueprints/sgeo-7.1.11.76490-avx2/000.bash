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
index 1018b3d6db8..48243a3991e 100644
--- a/indra/newview/installers/windows/installer_template.nsi
+++ b/indra/newview/installers/windows/installer_template.nsi
@@ -236,7 +236,7 @@ Function CheckCPUFlagsAVX2
     IntCmp $1 1 OK_AVX2
     ; AVX2 not supported
     MessageBox MB_OK $(MissingAVX2)
-    ${OpenURL} 'https://www.firestormviewer.org/early-access-beta-downloads-legacy-cpus'
+    ${OpenURL} 'https://github.com/humbletim/firestorm-gha/wiki/downloads-legacy-cpus#${VERSION_LONG}'
     Quit
 
   OK_AVX2:
@@ -253,7 +253,7 @@ Function CheckCPUFlagsAVX2_Prompt
   OK_AVX2:
     MessageBox MB_YESNO $(AVX2Available) IDYES DownloadAVX2 IDNO ContinueInstall
     DownloadAVX2:
-      ${OpenURL} 'https://www.firestormviewer.org/early-access-beta-downloads/'
+      ${OpenURL} 'https://github.com/humbletim/firestorm-gha/wiki/downloads-avx2-cpus#${VERSION_LONG}'
       Quit
     ContinueInstall:
       Pop $1
EOF
)
  git diff
  # git -C repo/viewer diff
  popd

  gha-cache-save $cache_id-repo-0000 repo/viewer  || exit 37
)
