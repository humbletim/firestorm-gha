#!/bin/bash
maybe-clone viewer ${hub:-github.com} $repo "$ref"
maybe-clone p373r github.com ${GITHUB_REPOSITORY} P373R_6.6.8

    pushd repo/viewer
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
+      ${OpenURL} 'https://github.com/humbletim/firestorm-gha/wiki/downloads-legacy-cpus#${VERSION_LONG}'
       Quit
     ContinueInstall:
       Pop $1
EOF
)
  git diff
  # git -C repo/viewer diff
  popd

