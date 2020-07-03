#pragma once
namespace vr {

std::string getOpenVRString(vr::IVRSystem* sys, vr::TrackedDeviceProperty prop) {
  vr::TrackedPropertyError error = vr::TrackedProp_Success;
  char buf[vr::k_unMaxPropertyStringSize];
  sys->GetStringTrackedDeviceProperty( vr::k_unTrackedDeviceIndex_Hmd, prop, buf, vr::k_unMaxPropertyStringSize, &error);
  return error == vr::TrackedProp_Success ? buf : llformat("openvr_err: %d", (int)error);
}

LLSD eyeInfoAsLLSD(vr::IVRSystem* sys, vr::EVREye eye) {
  float l,r,t,b;
  if (sys) sys->GetProjectionRaw( vr::Eye_Left, &l, &r, &t, &b);
  if (t < 0.0f) { std::swap(t, b); }
  return LLSD()
    .with("openvr_eye", (int)eye)
    .with("projection_raw", LLSD().with("l", l).with("r",r).with("b",b).with("t",t))
    .with("projection_degrees", LLSD()
      .with("l", atan(l)*RAD_TO_DEG)
      .with("r", atan(r)*RAD_TO_DEG)
      .with("b", atan(b)*RAD_TO_DEG)
      .with("t", atan(t)*RAD_TO_DEG)
    )
    .with("fieldOfView", (LLVector2(atan(r-l), atan(t-b)) * RAD_TO_DEG).getValue())
    .with("uvCenter", !sys ? LLSD() : LLVector2(
      sys->GetFloatTrackedDeviceProperty(vr::k_unTrackedDeviceIndex_Hmd, vr::Prop_LensCenterLeftU_Float),
      sys->GetFloatTrackedDeviceProperty(vr::k_unTrackedDeviceIndex_Hmd, vr::Prop_LensCenterLeftV_Float)
    ).getValue())
    ;
}

LLSD infoAsLLSD() {
  uint32_t pnWidth = 0, pnHeight = 0;
  auto sys = vr::VRSystem();
  if (sys) {
    sys->GetRecommendedRenderTargetSize( &pnWidth, &pnHeight );
  }
  
  return LLSD()
    .with("version", sys ? sys->GetRuntimeVersion() : "(n/a)")
    .with("model", sys ? getOpenVRString(sys, vr::Prop_ModelNumber_String) : "(n/a)")
    .with("ipd", sys ? sys->GetFloatTrackedDeviceProperty(vr::k_unTrackedDeviceIndex_Hmd, vr::Prop_UserIpdMeters_Float) : NAN)
    .with("leftEye", eyeInfoAsLLSD(sys, vr::Eye_Left))
    .with("rightEye", eyeInfoAsLLSD(sys, vr::Eye_Right))
    .with("recommended_size", llformat("%ux%u", pnWidth, pnHeight))
    .with("GL_RENDERER", ((const char *)glGetString(GL_RENDERER)))
    .with("GL_VERSION", ((const char *)glGetString(GL_VERSION)))
    // .with("FieldOfView", gVR.m_fFOV);
    ;
}
}//ns
