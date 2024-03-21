# firestorm-gha + vr
Build of the [Firestorm Viewer](https://www.firestormviewer.org/about/) + [P373R VR Mod](https://gsgrid.de/firestorm-vr-mod/) using Github Actions.

<!--![C/C++ CI](../../workflows/C/C++%20CI/badge.svg)-->

Download here: [Releases](../../releases/latest)

**WARNING**: VERY EXPERIMENTAL / PERFORMANCE VARIES -- Modern VR HMD systems have async reprojection (which helps prevent low frame rate nausea), but as it stands right now, accessing SL/OpenSim in VR mode is only for the very brave.

- See [P373R VR Mod Home Page](https://gsgrid.de/firestorm-vr-mod/) (includes instructions on activating VR mode)
- See [Original Firestorm Source Code](https://github.com/FirestormViewer/phoenix-firestorm)

Notes:
* On Windows:
  - App name and install location have been changed to "FirestormOS-VR-GHA" so installation can exist side-by-side with stock Firestorm.
  - App settings and cache are shared with stock Firestorm in `AppData/Roaming/Firestorm_x64` and `AppData/Local/FirestormOS_x64`
* Special Thanks to @thoys for sharing his Github Action wisdoms!
