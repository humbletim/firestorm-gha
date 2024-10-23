#!/bin/bash
maybe-clone viewer ${hub:-github.com} $repo "$ref"
maybe-clone p373r github.com ${GITHUB_REPOSITORY} P373R_6.6.8

    pushd repo/viewer
patch -p1 < <(cat <<'EOF'
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

