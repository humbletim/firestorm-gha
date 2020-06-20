#pragma once

#include <map>
#include <string>
extern llviewerVR gVR;

namespace vr {
  
  // remap legacy vrsettings.ini and gVR.m_f* values to conventional Firestorm global settings
  struct Settings {
    bool _vrStartupPending{ false };
    void update() {
      if (_vrStartupPending) {
        _vrStartupPending = false;
        LL_WARNS("vr::Settings") << "_vrStartupPending detected; calling vrStartup" << LL_ENDL;
        gVR.vrStartup(FALSE);
      }
    }
    
    std::map<std::string, LLControlVariablePtr> settings;
    void addSetting(std::string name, std::function<void(LLSD newValue)> onchange = [](LLSD){}) {
      if (LLControlVariablePtr ptr = gSavedSettings.getControl(name)) {
        ptr->getSignal()->connect([onchange](LLControlVariable *control, const LLSD& newValue, const LLSD& oldValue) {
          onchange(newValue);
        });
        settings[name] = ptr;
      } else {
          LL_WARNS("vr::Settings") << name << " control not found" << LL_ENDL;
      }
    }


    Settings() {
        // OpenVR toggle
        addSetting("$vrEnabled", [this](LLSD newValue) {
          LL_WARNS("vr::Settings") << "gVR.m_bVrEnabled = " << newValue.asBoolean() << LL_ENDL;
          gVR.m_bVrEnabled = newValue.asBoolean();
          if (!newValue.asBoolean()) {
            if (gVR.m_bVrActive) {
              LL_WARNS("vr::Settings") << "!gVR.m_bVrEnabled && gVR.m_bVrActive -- auto-disabling m_bVrActive" << LL_ENDL;
              if (settings["$vrActive"]) settings["$vrActive"]->setValue(false);
            }
            //   // TODO: if disabling VR maybe also save the values to the legacy .ini file?
            //   gVR.INISaveRead(true);
          }
          LL_WARNS("vr::Settings") << "trigger vrStartup" << LL_ENDL;
          gVR.vrStartup(FALSE);
          // LL_WARNS("vr::Settings") << "_vrStartupPending = true" << LL_ENDL;
          // _vrStartupPending = true;
        });
      
        // HMD output toggle
        addSetting("$vrActive", [this](LLSD newValue) {
          LL_WARNS("vr::Settings") << "gVR.m_bVrActive = " << newValue.asBoolean() << LL_ENDL;
      
          if (newValue.asBoolean()) {
            if (!gVR.m_bVrEnabled || !gVR.gHMD) {
              if (settings["$vrActive"]) settings["$vrActive"]->setValue(false); // prevent activating until VR is enabled
              return;
            }
          }
          gVR.m_bVrActive = newValue.asBoolean();
          if (gVR.m_bVrActive && gVR.gHMD) {
            LL_WARNS("vr::Settings") << "gHMD fov:" << gVR.m_fFOV << LL_ENDL;
            gVR.gHmdOffsetPos.mV[2] = 0;
            if (gVR.m_fFOV > 20) {
              LLViewerCamera::getInstance()->setDefaultFOV(gVR.m_fFOV * DEG_TO_RAD);
            }
          } else {
            LL_WARNS("vr::Settings") << "!gHMD " << gVR.hud_textp << " " << gVR.m_strHudText << LL_ENDL;
            if (gVR.hud_textp && !gVR.m_strHudText.empty()) {
              gVR.m_strHudText = "";
              gVR.hud_textp->setString(gVR.m_strHudText);
              gVR.hud_textp->setDoFade(FALSE);
              gVR.hud_textp->setHidden(TRUE);
             }
            LL_WARNS("vr::Settings") << "//!gHMD " << gVR.hud_textp << " " << gVR.m_strHudText << LL_ENDL;
          }
      });
      
      addSetting("$vrEyeDistance", [](LLSD newValue) { gVR.m_fEyeDistance = newValue.asReal(); });
      addSetting("$vrFocusDistance", [](LLSD newValue) { gVR.m_fFocusDistance = newValue.asReal(); });
      addSetting("$vrTextureShift", [](LLSD newValue) { gVR.m_fTextureShift = newValue.asReal(); });
      addSetting("$vrTextureZoom", [](LLSD newValue) { gVR.m_fTextureZoom = newValue.asReal(); });
      addSetting("$vrFieldOfView", [](LLSD newValue) { gVR.m_fFOV = newValue.asReal(); });
      addSetting("$vrConfigVersion");
    

      if (!settings["$vrConfigVersion"]) {
        LL_WARNS("vr::Settings") << "$vrConfigVersion setting missing :(" << LL_ENDL;
        return;
      }

      // potentially import legacy vrsettings.ini values
      {
        llstat stat_data{ 0 };
        std::string path = getenv("APPDATA") ? getenv("APPDATA") : "/tmp";
        path.append("\\Firestorm_x64\\vrconfig.ini");
        if (LLFile::stat(path, &stat_data)) {
            if (settings["$vrConfigVersion"]->getValue().asReal() < (LLSD::Real)stat_data.st_mtime) {
              LL_WARNS("vr::Settings") << "importing legacy vrsettings.ini values..." << settings["$vrConfigVersion"]->getValue().asReal() << " < " << stat_data.st_mtime << LL_ENDL;
              settings["$vrConfigVersion"]->setValue((LLSD::Real)stat_data.st_mtime);
              gVR.INISaveRead(false);
              if (settings["$vrEyeDistance"]) settings["$vrEyeDistance"]->setValue(gVR.m_fEyeDistance);
              if (settings["$vrFocusDistance"]) settings["$vrFocusDistance"]->setValue(gVR.m_fFocusDistance);
              if (settings["$vrTextureShift"]) settings["$vrTextureShift"]->setValue(gVR.m_fTextureShift);
              if (settings["$vrTextureZoom"]) settings["$vrTextureZoom"]->setValue(gVR.m_fTextureZoom);
              if (settings["$vrFieldOfView"]) settings["$vrFieldOfView"]->setValue(gVR.m_fFOV);
            }
        }
      }
    }
  };
  Settings* settings{ nullptr };
}

