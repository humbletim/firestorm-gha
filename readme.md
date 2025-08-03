# firestorm-gha + vr
Build of the [Firestorm Viewer](https://www.firestormviewer.org/about/) + [P373R VR Mod](https://gsgrid.de/firestorm-vr-mod/) using Github Actions.

Download here: [Releases](../../releases/latest)

**WARNING**: VERY EXPERIMENTAL / PERFORMANCE VARIES -- Modern VR HMD systems have async reprojection (which helps prevent low frame rate nausea), but as it stands right now, accessing SL/OpenSim in VR mode is only for the very brave.

See also:
- [Instructions](https://blog.inf.ed.ac.uk/atate/firestorm-vr-mod/) - Firestorm VR Mod \| Austin Tate's Blog
- [P373R VR Mod Home Page](https://gsgrid.de/firestorm-vr-mod/)

Upstream repos:
| name | repo | details |
| -- | -- | -- |
| **Firestorm** | [FirestormViewer/phoenix-firestorm](https://github.com/FirestormViewer/phoenix-firestorm) | base code the vr mod becomes applied to |
| **P373R** | [humbletim/p373r-vrmod](https://github.com/humbletim/p373r-vrmod) | patch set (original p373r vr mod changes) |
| **Sgeo Min** | [Sgeo/p373r-sgeo-minimal](https://github.com/Sgeo/p373r-sgeo-minimal/tree/sgeo_min_vr_7.1.9) | Sgeo's phoenix-firestorm devfork with p373r changes applied + other improvements |
