// timer / timeout helper (WIP)
// LL-specific VR glue code -- humbletim @ 2020.06.30
#pragma once
#include <llevents.h>
namespace tim {
  struct TimerListener {
    LLFrameTimer timer;
    LLTempBoundListener listener;
    std::function<void()> callback;
    int ms;
    TimerListener(std::function<void(TimerListener* self)> callback, int ms) : TimerListener([this,callback]{ callback(this); }, ms) {}
    TimerListener(std::function<void()> callback, int ms) :  callback(callback), ms(ms) {}
    virtual ~TimerListener() {}
    virtual bool expired() const { return timer.getElapsedTimeF32() >= ms/1000.0f; }
    bool update() {
      if (expired()) {
        listener.disconnect();
        callback();
      }
      return false;
    }
    void restart() {
      if (active()) timer.reset();
      else start();
    }
    bool active() const { return listener.connected(); }
    void start() {
      listener = LLEventPumps::instance().obtain("mainloop")
            .listen(LLEventPump::ANONYMOUS, boost::bind(&TimerListener::update, this));
      timer.reset();
    }
    void stop() { if (listener.connected()) listener.disconnect(); }
  };

  // std::shared_ptr<TimerListener> setTimeout(std::function<void()> func, int ms);
  // void setInterval(std::function<void()> func, int ms);
  inline void setImmediate(std::function<void()> func) {
    LLTempBoundListener* mBoundListener = new LLTempBoundListener();
    *mBoundListener = LLEventPumps::instance().obtain("mainloop").listen(LLEventPump::ANONYMOUS,
      [mBoundListener, func](const LLSD&) { delete mBoundListener; func(); return false; }
    );
  }
}//ns
