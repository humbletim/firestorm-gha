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
  static LLSD viewerInfoAsLLSD();
  
  // map gVR.m_f* values to conventional Firestorm global settings
  struct Settings {
    std::map<std::string, LLControlVariablePtr> settings;
    LLControlVariablePtr _addSetting(std::string name, std::function<void(LLSD newValue)> onchange = [](LLSD){});
    LLControlVariablePtr addSetting(std::string name, std::function<void(LLSD newValue)> onchange = [](LLSD){}) { return settings[name] = _addSetting(name, onchange); }
    LLControlVariablePtr addButtonlikeSetting(std::string name, std::function<void()> onclick);
    LLSD asLLSD();
    void resetToDefaults();
    Settings();
  };
}

namespace vr {
  void Settings::resetToDefaults() {
    for (auto &kv : settings) {
      if (kv.second) {
        LL_WARNS("vr::Settings") << "resetting " << kv.first << " = " << kv.second->getDefault() << LL_ENDL;
        kv.second->resetToDefault(true);
      }
    }
  }
  LLControlVariablePtr Settings::_addSetting(std::string name, std::function<void(LLSD newValue)> onchange) {
    auto ptr = gSavedSettings.getControl(name);
    if (ptr) {
      ptr->getSignal()->connect([onchange](LLControlVariable *control, const LLSD& newValue, const LLSD& oldValue) {
        onchange(newValue);
      });
    } else {
      LL_WARNS("vr::Settings") << name << " control not found" << LL_ENDL;
    }
    return ptr;
  }
  
  LLControlVariablePtr Settings::addButtonlikeSetting(std::string name, std::function<void()> onclick) {
    auto ptr = _addSetting(name, [name, onclick](LLSD newValue) {
      if (newValue.asBoolean()) {
        tim::setImmediate([name]{ gSavedSettings.getControl(name)->setValue(false); });
        onclick();
      }
    });
    return ptr;
  }

  Settings::Settings() {
      // OpenVR toggle
      // static tim::TimerListener cursorHider{ [](tim::TimerListener* self) {
      //   auto win = gViewerWindow->getWindow();
      //   auto visible = !gViewerWindow->getCursorHidden() || !win->isCursorHidden();
      //   LL_WARNS("vr::Settings") << "cursorHider m_bVrEnabled: " << gVR.m_bVrEnabled << " visible: " << visible << LL_ENDL;
      //   if (!gVR.m_bVrEnabled) {
      //     gViewerWindow->showCursor();
      //     return;
      //   }
      //   if (gVR.m_bVrEnabled && visible) {
      //     gViewerWindow->hideCursor();
      //   }
      //   self->restart();
      // }, 1000};
      _addSetting("$vrEnabled", [this](LLSD newValue) {
        LL_WARNS("vr::Settings") << "gVR.m_bVrEnabled = " << newValue.asBoolean() << LL_ENDL;
        gVR.m_bVrEnabled = newValue.asBoolean();

        if (gVR.m_bVrEnabled) {
          LL_WARNS("vr::Settings") << "trigger vrStartup" << LL_ENDL;
          gVR.vrStartup(FALSE);
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
        }
        // cursorHider.restart();
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

      _addSetting("$vrFullscreen", [](LLSD newValue) {
        applyVRUIScale(newValue.asBoolean());
        vr::toggleFullscreen();
        gViewerWindow->handleWindowDidChangeScreen(gViewerWindow->getWindow());
      });

      addSetting("$vrFullscreenUIScale", [](LLSD newValue) { uiscale_debouncer.restart(); });

      addSetting("$vrEyeDistance", [](LLSD newValue) {
        gVR.m_fEyeDistance = newValue.asReal();
        gVR.updateEyeToHeadTransforms();
      });
      addSetting("$vrFocusDistance", [](LLSD newValue) {
        gVR.m_fFocusDistance = newValue.asReal();
        gVR.updateEyeToHeadTransforms();
      });
      // addSetting("$vrTextureShift", [](LLSD newValue) {
      //   gVR.m_fTextureShift = newValue.asReal();
      //   gVR.clearFramebuffers();
      // });
      // addSetting("$vrTextureZoom", [](LLSD newValue) {
      //   gVR.m_fTextureZoom = newValue.asReal();
      //   gVR.clearFramebuffers();
      // });
      addSetting("$vrNearClip", [](LLSD newValue) { gVR.m_fNearClip = newValue.asReal(); });

      addSetting("$vrUIShift");
      addSetting("$vrFullscreenUIScale");
      addSetting("$vrConfigVersion");
      addSetting("$vrMouselookYawOnly");
      addSetting("$vrRightToolbarOffset");
      addSetting("$vrCursorZooming");
      
      // virtual command buttons
      addButtonlikeSetting("$vrRecenterHMD", []{
        if (auto func = LLUICtrl::CommitCallbackRegistry::getValue("VR.RecenterHMD")) {
          (*func)(nullptr, LLSD());
        }
      });

      addButtonlikeSetting("$vrCopySettingsToClipboard", [this]{
          auto json = Json::StyledWriter().write(LlsdToJson(
            LLSD()
              .with("FirestormVR", asLLSD()
                .with("renderBuffer", LLVector2(gVR.m_nRenderWidth, gVR.m_nRenderHeight).getValue())
                .with("scrSize", LLVector2(gVR.m_ScrSize.mX, gVR.m_ScrSize.mY).getValue())
              )
              .with("openvr", vr::infoAsLLSD())
              .with("viewer", viewerInfoAsLLSD())
          ));
          LL_WARNS("vr::Settings") << json << LL_ENDL;
          //gSavedSettings.setString("$vrStatus", json);
          LLView::getWindow()->copyTextToClipboard(utf8str_to_wstring(json));
          LLNotificationsUtil::add("GenericAlertOK", LLSD().with("MESSAGE", "(copied to clipboard)\n"+json), LLSD(), [](const LLSD& notification, const LLSD& response) {
            LL_WARNS("vr::Settings") << "notifictaion=" << notification << " response=" << response << " selected=" << LLNotificationsUtil::getSelectedOption(notification, response) << LL_ENDL;
            return false;
          });
      });
      
      addButtonlikeSetting("$vrResetDefaults", [this]{
        if (auto func = LLUICtrl::CommitCallbackRegistry::getValue("VR.ResetDefaults")) {
          (*func)(nullptr, LLSD());
        }
      });

      gVR.loadFromSettings();
    }

    LLSD Settings::asLLSD() {
      LLSD out;
      for (auto& kv : settings) {
        if (kv.second) out[kv.first] = kv.second->getValue();
      }
      return out;
    }
    
    static LLSD viewerInfoAsLLSD() {
      std::string timeStr = "[hour12, datetime, slt]:[min, datetime, slt]:[second, datetime, slt] [ampm, datetime, slt] [timezone,datetime, slt]";
      LLStringUtil::format(timeStr, LLSD().with("datetime", (S32) time_corrected()));

      return LLSD()
        .with("version", LLVersionInfo::getVersion())
        .with("channel", LLVersionInfo::getChannel())
        .with("hash", LLVersionInfo::getGitHash())
        .with("sltime", timeStr)
        .with("window_raw", llformat("%dx%d", gViewerWindow->getWindowWidthRaw(), gViewerWindow->getWindowHeightRaw()))
        .with("window_scaled", llformat("%dx%d", gViewerWindow->getWindowWidthScaled(), gViewerWindow->getWindowHeightScaled()))
        .with("mScreen", llformat("%dx%d", gPipeline.mScreen.getWidth(), gPipeline.mScreen.getHeight()))
      #ifdef SM_CXSCREEN
        .with("screen", llformat("%dx%d", GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN)))
      #endif
      #ifdef _WIN32
        .with("monitor", vr::win32::_getPrimaryMonitorSize().getValue())
        .with("desktop", vr::win32::_getPrimaryWorkareaSize().getValue())
      #endif
      #ifdef __linux__
        .with("desktop", _getPrimaryWorkareaSize().getValue())
      #endif
        .with("UIScaleFactor", gSavedSettings.getF32("UIScaleFactor"))
        .with("displayScale", gViewerWindow->getDisplayScale().mV[VX])
        .with("scaled_vs_raw", (F32)gViewerWindow->getWindowWidthScaled() / (F32)gViewerWindow->getWindowWidthRaw())
        .with("raw_vs_scaled", (F32)gViewerWindow->getWindowWidthRaw() / (F32)gViewerWindow->getWindowWidthScaled())
      #ifdef VK_CAPITAL
        .with("capslock", ((GetKeyState(VK_CAPITAL) & 0x0001) != 0))
      #endif
      ;
    }

}//ns

