// header-only module for dealing with live-editable VR settings -- humbletim @ 2020.06.30
#pragma once

#include <map>
#include <string>
extern llviewerVR gVR;

#include <llversioninfo.h>
#include <llsdjson.h>
#include "json/writer.h" // JSON
#include <llnotificationsutil.h>

namespace vr {
  struct Settings;
  Settings* settings{ nullptr };
  
  // map gVR.m_f* values to conventional Firestorm global settings
  struct Settings {
    std::map<std::string, LLControlVariablePtr> settings;
    LLControlVariablePtr addSetting(std::string name, std::function<void(LLSD newValue)> onchange = [](LLSD){});
    LLControlVariablePtr addButtonlikeSetting(std::string name, std::function<void()> onclick);
    static LLSD asLLSD();
    Settings();
  };
}

namespace vr {
  LLControlVariablePtr Settings::addSetting(std::string name, std::function<void(LLSD newValue)> onchange) {
    auto ptr = gSavedSettings.getControl(name);
    if (ptr) {
      ptr->getSignal()->connect([onchange](LLControlVariable *control, const LLSD& newValue, const LLSD& oldValue) {
        onchange(newValue);
      });
      settings[name] = ptr;
    } else {
      LL_WARNS("vr::Settings") << name << " control not found" << LL_ENDL;
    }
    return ptr;
  }
  
  LLControlVariablePtr Settings::addButtonlikeSetting(std::string name, std::function<void()> onclick) {
    return addSetting(name, [name, onclick](LLSD newValue) {
      if (newValue.asBoolean()) {
        tim::setImmediate([name]{ gSavedSettings.getControl(name)->setValue(false); });
        onclick();
      }
    });
  }

  Settings::Settings() {
      // OpenVR toggle
      addSetting("$vrEnabled", [this](LLSD newValue) {
        LL_WARNS("vr::Settings") << "gVR.m_bVrEnabled = " << newValue.asBoolean() << LL_ENDL;
        gVR.m_bVrEnabled = newValue.asBoolean();

        if (gVR.m_bVrEnabled) {
          LL_WARNS("vr::Settings") << "trigger vrStartup" << LL_ENDL;
          gVR.vrStartup(FALSE);
          gViewerWindow->hideCursor();
          tim::setImmediate([]{
              gSavedSettings.setString("$vrStatus", 
                llformat("HMD output [%ux%u]\nmScreen [%ux%u]", 
                  gVR.m_nRenderWidth, gVR.m_nRenderHeight,
                  gPipeline.mScreen.getWidth(), gPipeline.mScreen.getHeight()
                )
              );
          });
        } else {
          LL_WARNS("vr::Settings") << "trigger vr shutdown" << LL_ENDL;
          gVR.vrStartup(TRUE);
          gVR.hideHUD();
          gViewerWindow->showCursor();
        }
      });

      // kludge for supporting a fullscreen-specific UI scaling factor
      static const auto& applyVRUIScale = [](bool vrFullscreen){
        static LLCachedControl<F32> vrUIScale(gSavedSettings, "$vrFullscreenUIScale", 0.0f);
        static F32 originalScale{ 0.0f };
        if (LLApp::isExiting() || !vrFullscreen || !vrUIScale) {
          if (originalScale) {
            gSavedSettings.setF32("UIScaleFactor", originalScale);
            LL_WARNS("vr::Settings") << "restored UIScaleFactor: " << originalScale << LL_ENDL;
            originalScale = 0.0f;
          }
        } else if (vrUIScale) {
          if (!originalScale) originalScale = gSavedSettings.getF32("UIScaleFactor");
          gSavedSettings.setF32("UIScaleFactor", vrUIScale);
          LL_WARNS("vr::Settings") << "set custom VR UIScaleFactor: " << vrUIScale << LL_ENDL;
        }
      };
      // specialized TimerListener that defers until after the current interactive UI edit
      static struct MyTimerListener : public tim::TimerListener {
        MyTimerListener(std::function<void()> callback, int ms) : tim::TimerListener(callback, ms) {}
        virtual bool expired() const override {
          // prevent firing timeout while actively moving slider/spinner/etc.
          if (auto cur_focus = dynamic_cast<LLUICtrl*>(gFocusMgr.getKeyboardFocus())) {
            if (cur_focus->hasMouseCapture()) {
              return false;
            }
          }
          return tim::TimerListener::expired();
        }
      } uiscale_debouncer{[]{
        static LLCachedControl<bool> vrFullscreen(gSavedSettings, "$vrFullscreen", false);
        LL_WARNS("vr::Settings") << "uiscale_debouncer: " << vrFullscreen << LL_ENDL;
        applyVRUIScale(vrFullscreen);
        gViewerWindow->handleWindowDidChangeScreen(gViewerWindow->getWindow());
      }, 1000};

      addSetting("$vrFullscreen", [](LLSD newValue) {
        applyVRUIScale(newValue.asBoolean());
        vr::toggleFullscreen();
        gViewerWindow->handleWindowDidChangeScreen(gViewerWindow->getWindow());
      });

      addSetting("$vrFullscreenUIScale", [](LLSD newValue) { uiscale_debouncer.restart(); });

      addSetting("$vrEyeDistance", [](LLSD newValue) { gVR.m_fEyeDistance = newValue.asReal(); });
      addSetting("$vrFocusDistance", [](LLSD newValue) { gVR.m_fFocusDistance = newValue.asReal(); });
      // addSetting("$vrTextureShift", [](LLSD newValue) {
      //   gVR.m_fTextureShift = newValue.asReal();
      //   gVR.clearFramebuffers();
      // });
      // addSetting("$vrTextureZoom", [](LLSD newValue) {
      //   gVR.m_fTextureZoom = newValue.asReal();
      //   gVR.clearFramebuffers();
      // });
      addSetting("$vrNearClip", [](LLSD newValue) { gVR.m_fNearClip = newValue.asReal(); });

      // virtual command buttons
      addButtonlikeSetting("$vrRecenterHMD", []{
          gVR.recenterHMD();
          gVR.clearFramebuffers();
          gVR.hideHUD();

          std::stringstream s;
          F32 roll, pitch, yaw;
          gVR.inverseCamOffsetWorld.quaternion().getEulerAngles(&roll, &pitch, &yaw);
          LLVector3 deg = LLVector3{ pitch, yaw, roll } * RAD_TO_DEG;
          s << "HMD recentered\n";
          s << "trans: " << gVR.inverseCamOffsetWorld.getTranslation() << "\n";
          s << "rot: " << deg << "\n";
          gSavedSettings.setString("$vrStatus", s.str());
      });

      addButtonlikeSetting("$vrCopySettingsToClipboard", [this]{
          auto json = Json::StyledWriter().write(LlsdToJson(asLLSD()));
          LL_WARNS("vr::Settings") << json << LL_ENDL;
          //gSavedSettings.setString("$vrStatus", json);
          LLView::getWindow()->copyTextToClipboard(utf8str_to_wstring(json));
          LLNotificationsUtil::add("GenericAlertOK", LLSD().with("MESSAGE", "(copied to clipboard)\n"+json), LLSD(), [](const LLSD& notification, const LLSD& response) {
            LL_WARNS("vr::Settings") << "notifictaion=" << notification << " response=" << response << " selected=" << LLNotificationsUtil::getSelectedOption(notification, response) << LL_ENDL;
            return false;
          });
      });

      // restore member values from existing settings
      {
        gVR.m_fEyeDistance = gSavedSettings.getF32("$vrEyeDistance");
        gVR.m_fFocusDistance = gSavedSettings.getF32("$vrFocusDistance");
        // gVR.m_fTextureShift = gSavedSettings.getF32("$vrTextureShift");
        // gVR.m_fTextureZoom = gSavedSettings.getF32("$vrTextureZoom");
        gVR.m_fNearClip = gSavedSettings.getF32("$vrNearClip");
      }
    }

    LLSD Settings::asLLSD() {
      uint32_t pnWidth = 0;
      uint32_t pnHeight = 0;
      LLSD leftEye, rightEye;
      if (auto sys = vr::VRSystem()) {
        sys->GetRecommendedRenderTargetSize( &pnWidth, &pnHeight );
        {
          float l,r,t,b;
          sys->GetProjectionRaw( vr::Eye_Left, &l, &r, &t, &b);
          if (t < 0.0f) { std::swap(t, b); }
          leftEye["projection"] = LLSD().with("l", l).with("r",r).with("b",b).with("t",t);
          leftEye["fieldOfView"] = (LLVector2(atan(r-l), atan(t-b)) * RAD_TO_DEG).getValue();
          leftEye["uvCenter"] = LLVector2(
            sys->GetFloatTrackedDeviceProperty(vr::k_unTrackedDeviceIndex_Hmd, vr::Prop_LensCenterLeftU_Float),
            sys->GetFloatTrackedDeviceProperty(vr::k_unTrackedDeviceIndex_Hmd, vr::Prop_LensCenterLeftV_Float)
          ).getValue();
        }
        {
          float l,r,t,b;
          sys->GetProjectionRaw( vr::Eye_Right, &l, &r, &t, &b);
          if (t < 0.0f) { std::swap(t, b); }
          rightEye["projection"] = LLSD().with("l", l).with("r",r).with("b",b).with("t",t);
          rightEye["fieldOfView"] = (LLVector2(atan(r-l), atan(t-b)) * RAD_TO_DEG).getValue();
          rightEye["uvCenter"] = LLVector2(
            sys->GetFloatTrackedDeviceProperty(vr::k_unTrackedDeviceIndex_Hmd, vr::Prop_LensCenterRightU_Float),
            sys->GetFloatTrackedDeviceProperty(vr::k_unTrackedDeviceIndex_Hmd, vr::Prop_LensCenterRightV_Float)
          ).getValue();
        }
      }
      
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
          .with("uiShift", gSavedSettings.getF32("$vrUIShift"))
          .with("uiScaleFactor", gSavedSettings.getF32("UIScaleFactor"))
          .with("displayScale", gViewerWindow->getDisplayScale().mV[VX])
  #ifdef SM_CXSCREEN
          .with("screen", llformat("%dx%d", GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN)))
  #endif
  #ifdef _WIN32
          .with("monitor", vr::win32::_getPrimaryMonitorSize().getValue())
  #endif
  #ifdef VK_CAPITAL
          .with("capslock", ((GetKeyState(VK_CAPITAL) & 0x0001) != 0))
  #endif
        )
        .with("openvr", LLSD()
          .with("version", vr::VRSystem() ? vr::VRSystem()->GetRuntimeVersion() : "(n/a)")
          .with("model", gVR.gHMD ? gVR.GetTrackedDeviceString(gVR.gHMD, vr::k_unTrackedDeviceIndex_Hmd, vr::Prop_ModelNumber_String) : "(n/a)")
          .with("ipd", gVR.gHMD ? gVR.gHMD->GetFloatTrackedDeviceProperty(vr::k_unTrackedDeviceIndex_Hmd, vr::Prop_UserIpdMeters_Float) : NAN)
          .with("leftEye", leftEye)
          .with("rightEye", rightEye)
          .with("recommended_size", llformat("%ux%u", pnWidth, pnHeight))
          .with("render_size", llformat("%ux%u", gVR.m_nRenderWidth, gVR.m_nRenderHeight))
          .with("GL_RENDERER", ((const char *)glGetString(GL_RENDERER)))
          .with("GL_VERSION", ((const char *)glGetString(GL_VERSION)))
        )
        .with("EyeDistance", gVR.m_fEyeDistance)
        .with("FocusDistance", gVR.m_fFocusDistance)
        .with("TextureShift", gVR.m_fTextureShift)
        .with("TextureZoom", gVR.m_fTextureZoom)
        // .with("FieldOfView", gVR.m_fFOV);
        ;
  }
}//ns

