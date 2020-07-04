#pragma once

#include <map>
#include <string>
extern llviewerVR gVR;

#include <llversioninfo.h>
#include <llsdjson.h>
#include "json/writer.h" // JSON
#include <llnotificationsutil.h>

namespace vr {
  
  // remap legacy vrsettings.ini and gVR.m_f* values to conventional Firestorm global settings
  struct Settings {
    LLSD asLLSD() {
      uint32_t pnWidth = 0;
      uint32_t pnHeight = 0;
      if (vr::VRSystem()) vr::VRSystem()->GetRecommendedRenderTargetSize( &pnWidth, &pnHeight );
      std::string timeStr = "[hour12, datetime, slt]:[min, datetime, slt]:[second, datetime, slt] [ampm, datetime, slt] [timezone,datetime, slt]";
      LLStringUtil::format(timeStr, LLSD().with("datetime", (S32) time_corrected()));

      return LLSD()
        .with("viewer", LLSD()
          .with("version", LLVersionInfo::getVersion())
          .with("channel", LLVersionInfo::getChannel())
          .with("hash", LLVersionInfo::getGitHash())
          .with("sltime", timeStr)
          .with("window_raw", llformat("%dx%d", gViewerWindow->getWindowWidthRaw(), gViewerWindow->getWindowHeightRaw()))
          .with("window_scaled", llformat("%dx%d", gViewerWindow->getWindowWidthScaled(), gViewerWindow->getWindowHeightScaled()))
  #if LL_WINDOWS
          .with("screen", llformat("%dx%d", GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN)))
  #endif
        )
        .with("openvr", LLSD()
          .with("version", vr::VRSystem() ? vr::VRSystem()->GetRuntimeVersion() : "(n/a)")
          .with("model", gVR.gHMD ? gVR.GetTrackedDeviceString(gVR.gHMD, vr::k_unTrackedDeviceIndex_Hmd, vr::Prop_ModelNumber_String) : "(n/a)")
          .with("recommended_size", llformat("%ux%u", pnWidth, pnHeight))
          .with("render_size", llformat("%ux%u", gVR.m_nRenderWidth, gVR.m_nRenderHeight))
          .with("GL_RENDERER", ((const char *)glGetString(GL_RENDERER)))
          .with("GL_VERSION", ((const char *)glGetString(GL_VERSION)))
        )
        .with("EyeDistance", gVR.m_fEyeDistance)
        .with("FocusDistance", gVR.m_fFocusDistance)
        .with("TextureShift", gVR.m_fTextureShift)
        .with("TextureZoom", gVR.m_fTextureZoom)
        .with("FieldOfView", gVR.m_fFOV);
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

    void _deferred(std::function<void()> func) {
      LLTempBoundListener* mBoundListener = new LLTempBoundListener();
      *mBoundListener = LLEventPumps::instance().obtain("mainloop").listen(LLEventPump::ANONYMOUS,
        [mBoundListener, func](const LLSD&) { delete mBoundListener; func(); return false; }
      );  
    }
    Settings() {
        // OpenVR toggle
        addSetting("$vrEnabled", [this](LLSD newValue) {
          LL_WARNS("vr::Settings") << "gVR.m_bVrEnabled = " << newValue.asBoolean() << LL_ENDL;
          gVR.m_bVrEnabled = newValue.asBoolean();
          if (!newValue.asBoolean()) {
            if (gVR.m_bVrActive) {
              LL_WARNS("vr::Settings") << "!gVR.m_bVrEnabled && gVR.m_bVrActive -- auto-disabling m_bVrActive" << LL_ENDL;
              _deferred([this]{
                  LL_WARNS("vr::Settings") << "///!gVR.m_bVrEnabled && gVR.m_bVrActive -- auto-disabling m_bVrActive" << LL_ENDL;
                  settings["$vrActive"]->setValue(false);
              });
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
      
          static const auto hide_hud = []{
            if (gVR.hud_textp) {
              gVR.m_strHudText = "";
              gVR.hud_textp->setString(gVR.m_strHudText);
              gVR.hud_textp->setDoFade(FALSE);
              gVR.hud_textp->setHidden(TRUE);
             }
          };
          if (newValue.asBoolean()) {
            if (!gVR.m_bVrEnabled || !gVR.gHMD) {
              _deferred([this]{
                LL_WARNS("vr::Settings") << "///auto-disabling m_bVrActive" << LL_ENDL;
                settings["$vrActive"]->setValue(false);
                gSavedSettings.setString("$vrStatus", !gVR.m_bVrEnabled ? "(enable vr first)" : "(!gHMD)");
              });
              hide_hud();
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
            gSavedSettings.setString("$vrStatus", llformat("HMD output [%ux%u]", gVR.m_nRenderWidth, gVR.m_nRenderHeight));
          } else {
            LL_WARNS("vr::Settings") << "!gHMD " << gVR.hud_textp << " " << gVR.m_strHudText << LL_ENDL;
            hide_hud();
          }
      });
      
      addSetting("$vrEyeDistance", [](LLSD newValue) { gVR.m_fEyeDistance = newValue.asReal(); });
      addSetting("$vrFocusDistance", [](LLSD newValue) { gVR.m_fFocusDistance = newValue.asReal(); });
      addSetting("$vrTextureShift", [](LLSD newValue) { gVR.m_fTextureShift = newValue.asReal(); });
      addSetting("$vrTextureZoom", [](LLSD newValue) { gVR.m_fTextureZoom = newValue.asReal(); });
      addSetting("$vrFieldOfView", [](LLSD newValue) { 
        gVR.m_fFOV = newValue.asReal();
        if (gVR.gHMD) {
          LLViewerCamera::getInstance()->setDefaultFOV(gVR.m_fFOV * DEG_TO_RAD);
        }
      });
      addSetting("$vrCamRotOffset", [](LLSD newValue) { gVR.m_fCamRotOffset = newValue.asReal(); });
      addSetting("$vrConfigVersion");

      addSetting("$vrCopySettingsToClipboard", [this](LLSD newValue) {
        if (newValue.asBoolean()) {
          _deferred([this]{
            LL_WARNS("vr::Settings") << "///auto-disabling vrCopySettingsToClipboard" << LL_ENDL;
            settings["$vrCopySettingsToClipboard"]->setValue(false);
          });
          auto json = Json::StyledWriter().write(LlsdToJson(asLLSD()));
          LL_WARNS("vr::Settings") << json << LL_ENDL;
          //gSavedSettings.setString("$vrStatus", json);
          LLView::getWindow()->copyTextToClipboard(utf8str_to_wstring(json));
          LLNotificationsUtil::add("GenericAlertOK", LLSD().with("MESSAGE", "(copied to clipboard)\n"+json));
        }
      });

      // potentially import legacy vrsettings.ini values
      if (settings["$vrConfigVersion"]) {
        llstat stat_data{ 0 };
        std::string path = getenv("APPDATA") ? getenv("APPDATA") : "/tmp";
        path.append("\\Firestorm_x64\\vrconfig.ini");
        if (LLFile::stat(path, &stat_data)) {
            if (settings["$vrConfigVersion"]->getValue().asReal() < (LLSD::Real)stat_data.st_mtime) {
              LL_WARNS("vr::Settings") << "importing legacy vrsettings.ini values..." << settings["$vrConfigVersion"]->getValue().asReal() << " < " << stat_data.st_mtime << LL_ENDL;
              settings["$vrConfigVersion"]->setValue((LLSD::Real)stat_data.st_mtime);
              gVR.INISaveRead(false);
              gSavedSettings.setF32("$vrEyeDistance", gVR.m_fEyeDistance);
              gSavedSettings.setF32("$vrFocusDistance", gVR.m_fFocusDistance);
              gSavedSettings.setF32("$vrTextureShift", gVR.m_fTextureShift);
              gSavedSettings.setF32("$vrTextureZoom", gVR.m_fTextureZoom);
              gSavedSettings.setF32("$vrFieldOfView", gVR.m_fFOV);
            }
        }
      }
    }
  };
  Settings* settings{ nullptr };
}

