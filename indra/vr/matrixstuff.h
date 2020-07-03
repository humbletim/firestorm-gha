// latest attempt to use OpenVR-provided eye, head and projection matrices -- humbletim 2020.06.22
#pragma once

namespace tim {
  LLQuaternion fromPitchYawRollDegrees(F32 pitch, F32 yaw, F32 roll) {
    //return LLQuaternion().mayaQ(pitch, yaw, roll, LLQuaternion::XYZ);
    return LLQuaternion().setEulerAngles(roll * DEG_TO_RAD, pitch * DEG_TO_RAD, yaw * DEG_TO_RAD);
  }
  LLMatrix4 yawOnly(const LLMatrix4& mat) {
    auto tmp = mat.quaternion();
    tmp.mQ[VX] = tmp.mQ[VY] = 0.0f;
    tmp.normalize();
    return LLMatrix4(tmp, LLVector4(mat.getTranslation()));
  }
}
namespace vrx {
  template <typename TO, typename FROM> TO convert(FROM const&);
  // openvr 3x4 <=> LLMatrix4
  template<> inline LLMatrix4 convert(vr::HmdMatrix34_t const& matPose) {
    LLMatrix4 m4;
    auto& mMatrix = m4.mMatrix; 
    mMatrix[0][0] = matPose.m[0][0]; 
    mMatrix[0][1] = matPose.m[1][0]; 
    mMatrix[0][2] = matPose.m[2][0];
  
    mMatrix[1][0] = matPose.m[0][1]; 
    mMatrix[1][1] = matPose.m[1][1]; 
    mMatrix[1][2] = matPose.m[2][1];

    mMatrix[2][0] = matPose.m[0][2]; 
    mMatrix[2][1] = matPose.m[1][2]; 
    mMatrix[2][2] = matPose.m[2][2];

    mMatrix[3][0] = matPose.m[0][3]; 
    mMatrix[3][1] = matPose.m[1][3]; 
    mMatrix[3][2] = matPose.m[2][3];
    return m4;
  }
  template<> inline LLMatrix4 convert(const glh::matrix4f &mat) {
    LLMatrix4 m4;
    auto& mMatrix = m4.mMatrix; 
    mMatrix[0][0] = mat.element(0,0); 
    mMatrix[0][1] = mat.element(0,1); 
    mMatrix[0][2] = mat.element(0,2); 
    mMatrix[0][3] = mat.element(0,3); 

    mMatrix[1][0] = mat.element(1,0); 
    mMatrix[1][1] = mat.element(1,1); 
    mMatrix[1][2] = mat.element(1,2); 
    mMatrix[1][3] = mat.element(1,3); 

    mMatrix[2][0] = mat.element(2,0); 
    mMatrix[2][1] = mat.element(2,1); 
    mMatrix[2][2] = mat.element(2,2); 
    mMatrix[2][3] = mat.element(2,3); 

    mMatrix[3][0] = mat.element(3,0); 
    mMatrix[3][1] = mat.element(3,1); 
    mMatrix[3][2] = mat.element(3,2); 
    mMatrix[3][3] = mat.element(3,3); 
    return m4;
  }
}//ns

namespace tim {
  glh::matrix4f calculatePerspectiveMatrixFromHalfTangents(float l, float r, float b, float t, float n, float f) {
    // adapt half tangents to fall on near clip plane
    // see: https://github.com/ValveSoftware/openvr/wiki/IVRSystem::GetProjectionRaw
    l *= n;
    r *= n;
    b *= n;
    t *= n;
    
    // see: (7) http://kgeorge.github.io/2014/03/08/calculating-opengl-perspective-matrix-from-opencv-intrinsic-matrix 
    return glh::matrix4f(
      2*n/(r-l), 0,          (r+l)/(r-l),  0,
      0,         2*n/(t-b),  (t+b)/(t-b),  0,
      0,         0,          -(f+n)/(f-n), (-2*f*n)/(f-n),
      0,         0,          -1,           0
    );
  }

  // adapt OpenVR matrix to SL coordinate system
  // FIXME: this appears to work, but was largely arrived at through trial and error
  LLMatrix4 _openvr_to_sl(const LLMatrix4& m) {
    static const LLMatrix4 REHANDED {
      tim::fromPitchYawRollDegrees(0, -90,  0) *
      tim::fromPitchYawRollDegrees(0,   0, 90)
    };
    static const LLMatrix4 ROTXZ {
      tim::fromPitchYawRollDegrees(-90,0,90)
    };
    LLMatrix4 out;
    out *= REHANDED;
    out *= m;
    out *= ROTXZ;
    return out;
  } 
  
  // compose MODELVIEW_MATRIX from component matrices
  // FIXME: this appears to work, but was largely arrived at through trial and error
  LLMatrix4 calculateViewMatrix(
    const LLMatrix4& stockViewerCamera,
    const LLMatrix4& inverseCamOffset,
    const LLMatrix4& eyeToHead,
    const LLMatrix4& headToPlayspace
  ) {
    static const LLMatrix4 FLIPY { tim::fromPitchYawRollDegrees( 0, 180, 0 ) };
    static const LLMatrix4 FLIPZ { tim::fromPitchYawRollDegrees( 0, 0, 180 ) };
    LLMatrix4 out;
    LLMatrix4 hmd { FLIPY };
    LLMatrix4 aaaa = eyeToHead;
    aaaa *= LLMatrix4(headToPlayspace);
    hmd *= aaaa;
    out *= _openvr_to_sl(hmd);
    out *= inverseCamOffset;
    out *= FLIPZ;
    out *= stockViewerCamera;
    return out;
  }
  // configure Camera view from an arbitrary LLMatrix4 value
  void setCameraMatrix(const LLMatrix4& viewMatrix) {
    LLCoordFrame frame{ viewMatrix };
    LLVector3 origin = frame.getOrigin();
    LLVector3 up = frame.getUpAxis();
    LLVector3 point_of_interest = frame.getOrigin() + frame.getAtAxis();
    LLViewerCamera::getInstance()->lookAt(origin, point_of_interest, up);
  }
}//ns

// /OpenVR Matrices
