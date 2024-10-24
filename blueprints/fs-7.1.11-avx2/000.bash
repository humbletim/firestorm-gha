#!/bin/bash
maybe-clone viewer ${hub:-github.com} $repo "$ref"
maybe-clone p373r github.com ${GITHUB_REPOSITORY} P373R_6.6.8

    pushd repo/viewer
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

