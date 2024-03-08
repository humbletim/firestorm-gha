#include "llviewerprecompiledheaders.h"
#include "llviewerVR.h"
#include "llviewerwindow.h"
#ifdef _WIN32
#include "llwindowwin32.h"
#endif
#include "llviewercontrol.h"
#include "llviewercamera.h"
#include "llagentcamera.h"
#include "pipeline.h"
#include "llagent.h"
#ifdef _WIN32
#include "llkeyboardwin32.h"
#endif
#include "llui.h"

#include "llfloaterreg.h"
#include <fstream>
#include <iostream>
#include <vector>
//#include "llrender.h"

#ifdef _WIN32
#pragma comment(lib, "openvr_api")
#endif

#ifndef _WIN32
#define sprintf_s(buffer, buffer_size, stringbuffer, ...) (sprintf(buffer, stringbuffer, __VA_ARGS__))
#endif

//#include <time.h>
//#include <sys/time.h>
llviewerVR::llviewerVR()
{
	gHMD = NULL;
	gRenderModels = NULL;
	leftEyeDesc.m_nResolveTextureId = 0;
	rightEyeDesc.m_nResolveTextureId = 0;
	hud_textp = NULL;
	m_kEditKey = KEY_F4;
	m_kDebugKey = KEY_F3;
	m_kMenuKey = KEY_F5;
	m_kPlusKey = KEY_F6;
	m_kMinusKey = KEY_F7;
	m_fEyeDistance = 65;
	m_fFocusDistance = 10;
	m_fTextureShift = 0;
	m_fTextureZoom = 0;
	m_fFOV = 100;

	/*if (!LLKeyboard::keyFromString("x", &m_kEditKey))
	{
	// If the call failed, don't match any key.
	//key = KEY_NONE;
	}*/
}
LLPanel* panelp = NULL;
//GLenum err;

llviewerVR::~llviewerVR()
{
}

/*glh::matrix4f ConvertSteamVRMatrixToMatrix4(const vr::HmdMatrix34_t &matPose)
{
glh::matrix4f matrixObj(
matPose.m[0][0], matPose.m[1][0], matPose.m[2][0], 0.0,
matPose.m[0][1], matPose.m[1][1], matPose.m[2][1], 0.0,
matPose.m[0][2], matPose.m[1][2], matPose.m[2][2], 0.0,
matPose.m[0][3], matPose.m[1][3], matPose.m[2][3], 1.0f
);
return matrixObj;
}*/
//unused
vr::HmdQuaternion_t llviewerVR::GetRotation(vr::HmdMatrix34_t matrix) {
	vr::HmdQuaternion_t q;

	q.w = sqrt(fmax(0, 1 + matrix.m[0][0] + matrix.m[1][1] + matrix.m[2][2])) / 2;
	q.x = sqrt(fmax(0, 1 + matrix.m[0][0] - matrix.m[1][1] - matrix.m[2][2])) / 2;
	q.y = sqrt(fmax(0, 1 - matrix.m[0][0] + matrix.m[1][1] - matrix.m[2][2])) / 2;
	q.z = sqrt(fmax(0, 1 - matrix.m[0][0] - matrix.m[1][1] + matrix.m[2][2])) / 2;
	q.x = copysign(q.x, matrix.m[2][1] - matrix.m[1][2]);
	q.y = copysign(q.y, matrix.m[0][2] - matrix.m[2][0]);
	q.z = copysign(q.z, matrix.m[1][0] - matrix.m[0][1]);
	return q;
}

LLMatrix4 llviewerVR::ConvertGLHMatrix4ToLLMatrix4(glh::matrix4f m)
{
	LLMatrix4 mout;
	mout.mMatrix[0][0] = m.element(0, 0);
	mout.mMatrix[0][1] = m.element(1, 0);
	mout.mMatrix[0][2] = m.element(2, 0);
	mout.mMatrix[0][3] = m.element(3, 0);

	mout.mMatrix[1][0] = m.element(0, 1);
	mout.mMatrix[1][1] = m.element(1, 1);
	mout.mMatrix[1][2] = m.element(2, 1);
	mout.mMatrix[1][3] = m.element(3, 1);

	mout.mMatrix[2][0] = m.element(0, 2);
	mout.mMatrix[2][1] = m.element(1, 2);
	mout.mMatrix[2][2] = m.element(2, 2);
	mout.mMatrix[2][3] = m.element(3, 2);

	mout.mMatrix[3][0] = m.element(0, 3);
	mout.mMatrix[3][1] = m.element(1, 3);
	mout.mMatrix[3][2] = m.element(2, 3);
	mout.mMatrix[3][3] = m.element(3, 3);
	return mout;
}

glh::matrix4f llviewerVR::ConvertSteamVRMatrixToMatrix42(const vr::HmdMatrix34_t &matPose)
{
	//vr::HmdQuaternion_t q = GetRotation(matPose);

	//gHMDQuat.set(q.x,q.y,q.z,q.w);

	glh::matrix4f matrixObj(
		matPose.m[0][0], matPose.m[1][0], matPose.m[2][0], 0.0,
		matPose.m[0][1], matPose.m[1][1], matPose.m[2][1], 0.0,
		matPose.m[0][2], matPose.m[1][2], matPose.m[2][2], 0.0,
		matPose.m[0][3], matPose.m[1][3], matPose.m[2][3], 1.0
		//0, 0, 0, 1.0f
		);

	//LLMatrix4  mat((F32*)matPose.m);
	//gHMDQuat.setQuat(mat);


	//m_nPos.v[0] = matPose.m[0][3];
	//m_nPos.v[1] = matPose.m[2][3];
	//m_nPos.v[2] = matPose.m[1][3];

	//gHMDAxes.mV[0] = atan2(matPose.m[1][0], matPose.m[0][0]);// *57.2957795;//yaw
	//gHMDAxes.mV[2] = atan2(matPose.m[2][1], matPose.m[2][2]);// *57.2957795;//pitch

	//gHMDAxes.mV[0] = matPose.m[2][0];
	//gHMDAxes.mV[1] = matPose.m[2][1];
	//gHMDAxes.mV[2] = matPose.m[2][2];
	return matrixObj;
}

glh::matrix4f llviewerVR::GetHMDMatrixProjectionEye(vr::Hmd_Eye nEye)
{
	if (gHMD == NULL)
		return glh::matrix4f();

	vr::HmdMatrix44_t mat = gHMD->GetProjectionMatrix(nEye, m_fNearClip, m_fFarClip);

	return glh::matrix4f(
		mat.m[0][0], mat.m[1][0], mat.m[2][0], mat.m[3][0],
		mat.m[0][1], mat.m[1][1], mat.m[2][1], mat.m[3][1],
		mat.m[0][2], mat.m[1][2], mat.m[2][2], mat.m[3][2],
		mat.m[0][3], mat.m[1][3], mat.m[2][3], mat.m[3][3]
		);
}

glh::matrix4f llviewerVR::GetHMDMatrixPoseEye(vr::Hmd_Eye nEye)
{
	if (gHMD == NULL)
		return glh::matrix4f();

	vr::HmdMatrix34_t matEyeRight = gHMD->GetEyeToHeadTransform(nEye);
	return glh::matrix4f(
		matEyeRight.m[0][0], matEyeRight.m[1][0], matEyeRight.m[2][0], 0.0,
		matEyeRight.m[0][1], matEyeRight.m[1][1], matEyeRight.m[2][1], 0.0,
		matEyeRight.m[0][2], matEyeRight.m[1][2], matEyeRight.m[2][2], 0.0,
		matEyeRight.m[0][3], matEyeRight.m[1][3], matEyeRight.m[2][3], 1.0f
		);
	//glh::matrix4f mt;
	//return matrixObj.inverse();
	//gluInvertMatrix(matrixObj.m, mt.m);
	//return matrixObj;
}

//unused Gives the projection matrix for an eye  with HMD and IPD offsets. Add positional camera offset????

//Copy both matrices at startup?????
glh::matrix4f llviewerVR::GetCurrentViewProjectionMatrix(vr::Hmd_Eye nEye)
{
	if (gHMD == NULL)
		return glh::matrix4f();
	return GetHMDMatrixProjectionEye(nEye) * GetHMDMatrixPoseEye(nEye) * m_mat4HMDPose;
}

//debug func
std::string llviewerVR::MatrixToStr(glh::matrix4f mat, std::string name)
{

	std::string str(name);
	glh::ns_float::vec4 row;
	row = mat.get_row(0);
	str.append("\nLf Row 0 =< ");
	str.append(std::to_string(row.v[0]));
	str.append(" , ");
	str.append(std::to_string(-row.v[2]));
	str.append(" , ");
	str.append(std::to_string(row.v[1]));
	str.append(" , ");
	str.append(std::to_string(row.v[3]));
	str.append(" >\n ");

	row = mat.get_row(1);
	str.append("Up Row 1 =< ");
	str.append(std::to_string(row.v[0]));
	str.append(" , ");
	str.append(std::to_string(-row.v[2]));
	str.append(" , ");
	str.append(std::to_string(row.v[1]));
	str.append(" , ");
	str.append(std::to_string(row.v[3]));
	str.append(" > \n ");

	row = mat.get_row(2);
	str.append("Fw Row 2 =< ");
	str.append(std::to_string(row.v[0]));
	str.append(" , ");
	str.append(std::to_string(-row.v[2]));
	str.append(" , ");
	str.append(std::to_string(row.v[1]));
	str.append(" , ");
	str.append(std::to_string(row.v[3]));
	str.append(" > \n ");

	row = mat.get_row(3);
	str.append("po Row 3 =< ");
	str.append(std::to_string(row.v[0]));
	str.append(" , ");
	str.append(std::to_string(-row.v[2]));
	str.append(" , ");
	str.append(std::to_string(row.v[1]));
	str.append(" , ");
	str.append(std::to_string(row.v[3]));
	str.append(" > \n\n ");






	return str;
}

//Debug func
std::string llviewerVR::MatrixToStrLL(glh::matrix4f mat, std::string name)
{

	std::string str(name);
	glh::ns_float::vec4 row;
	row = mat.get_row(0);
	str.append("\nLf Row 0 =< ");
	str.append(std::to_string(row.v[0]));
	str.append(" , ");
	str.append(std::to_string(row.v[1]));
	str.append(" , ");
	str.append(std::to_string(row.v[2]));
	str.append(" , ");
	str.append(std::to_string(row.v[3]));
	str.append(" >\n ");

	row = mat.get_row(1);
	str.append("Up Row 1 =< ");
	str.append(std::to_string(row.v[0]));
	str.append(" , ");
	str.append(std::to_string(row.v[1]));
	str.append(" , ");
	str.append(std::to_string(row.v[2]));
	str.append(" , ");
	str.append(std::to_string(row.v[3]));

	str.append(" > \n ");

	row = mat.get_row(2);
	str.append("Fw Row 2 =< ");
	str.append(std::to_string(row.v[0]));
	str.append(" , ");
	str.append(std::to_string(row.v[1]));
	str.append(" , ");
	str.append(std::to_string(row.v[2]));
	str.append(" , ");
	str.append(std::to_string(row.v[3]));
	str.append(" > \n ");

	row = mat.get_row(3);
	str.append("po Row 3 =< ");
	str.append(std::to_string(row.v[0]));
	str.append(" , ");
	str.append(std::to_string(row.v[1]));
	str.append(" , ");
	str.append(std::to_string(row.v[2]));
	str.append(" , ");
	str.append(std::to_string(row.v[3]));
	str.append(" > \n\n ");






	return str;
}

bool llviewerVR::gluInvertMatrix(const float m[16], float invOut[16])
{
	float inv[16], det;
	int i;

	inv[0] = m[5] * m[10] * m[15] -
		m[5] * m[11] * m[14] -
		m[9] * m[6] * m[15] +
		m[9] * m[7] * m[14] +
		m[13] * m[6] * m[11] -
		m[13] * m[7] * m[10];

	inv[4] = -m[4] * m[10] * m[15] +
		m[4] * m[11] * m[14] +
		m[8] * m[6] * m[15] -
		m[8] * m[7] * m[14] -
		m[12] * m[6] * m[11] +
		m[12] * m[7] * m[10];

	inv[8] = m[4] * m[9] * m[15] -
		m[4] * m[11] * m[13] -
		m[8] * m[5] * m[15] +
		m[8] * m[7] * m[13] +
		m[12] * m[5] * m[11] -
		m[12] * m[7] * m[9];

	inv[12] = -m[4] * m[9] * m[14] +
		m[4] * m[10] * m[13] +
		m[8] * m[5] * m[14] -
		m[8] * m[6] * m[13] -
		m[12] * m[5] * m[10] +
		m[12] * m[6] * m[9];

	inv[1] = -m[1] * m[10] * m[15] +
		m[1] * m[11] * m[14] +
		m[9] * m[2] * m[15] -
		m[9] * m[3] * m[14] -
		m[13] * m[2] * m[11] +
		m[13] * m[3] * m[10];

	inv[5] = m[0] * m[10] * m[15] -
		m[0] * m[11] * m[14] -
		m[8] * m[2] * m[15] +
		m[8] * m[3] * m[14] +
		m[12] * m[2] * m[11] -
		m[12] * m[3] * m[10];

	inv[9] = -m[0] * m[9] * m[15] +
		m[0] * m[11] * m[13] +
		m[8] * m[1] * m[15] -
		m[8] * m[3] * m[13] -
		m[12] * m[1] * m[11] +
		m[12] * m[3] * m[9];

	inv[13] = m[0] * m[9] * m[14] -
		m[0] * m[10] * m[13] -
		m[8] * m[1] * m[14] +
		m[8] * m[2] * m[13] +
		m[12] * m[1] * m[10] -
		m[12] * m[2] * m[9];

	inv[2] = m[1] * m[6] * m[15] -
		m[1] * m[7] * m[14] -
		m[5] * m[2] * m[15] +
		m[5] * m[3] * m[14] +
		m[13] * m[2] * m[7] -
		m[13] * m[3] * m[6];

	inv[6] = -m[0] * m[6] * m[15] +
		m[0] * m[7] * m[14] +
		m[4] * m[2] * m[15] -
		m[4] * m[3] * m[14] -
		m[12] * m[2] * m[7] +
		m[12] * m[3] * m[6];

	inv[10] = m[0] * m[5] * m[15] -
		m[0] * m[7] * m[13] -
		m[4] * m[1] * m[15] +
		m[4] * m[3] * m[13] +
		m[12] * m[1] * m[7] -
		m[12] * m[3] * m[5];

	inv[14] = -m[0] * m[5] * m[14] +
		m[0] * m[6] * m[13] +
		m[4] * m[1] * m[14] -
		m[4] * m[2] * m[13] -
		m[12] * m[1] * m[6] +
		m[12] * m[2] * m[5];

	inv[3] = -m[1] * m[6] * m[11] +
		m[1] * m[7] * m[10] +
		m[5] * m[2] * m[11] -
		m[5] * m[3] * m[10] -
		m[9] * m[2] * m[7] +
		m[9] * m[3] * m[6];

	inv[7] = m[0] * m[6] * m[11] -
		m[0] * m[7] * m[10] -
		m[4] * m[2] * m[11] +
		m[4] * m[3] * m[10] +
		m[8] * m[2] * m[7] -
		m[8] * m[3] * m[6];

	inv[11] = -m[0] * m[5] * m[11] +
		m[0] * m[7] * m[9] +
		m[4] * m[1] * m[11] -
		m[4] * m[3] * m[9] -
		m[8] * m[1] * m[7] +
		m[8] * m[3] * m[5];

	inv[15] = m[0] * m[5] * m[10] -
		m[0] * m[6] * m[9] -
		m[4] * m[1] * m[10] +
		m[4] * m[2] * m[9] +
		m[8] * m[1] * m[6] -
		m[8] * m[2] * m[5];

	det = m[0] * inv[0] + m[1] * inv[4] + m[2] * inv[8] + m[3] * inv[12];

	if (det == 0)
		return false;

	det = 1.0 / det;

	for (i = 0; i < 16; i++)
		invOut[i] = inv[i] * det;

	return true;
}

void llviewerVR::UpdateHMDMatrixPose()
{
	if (gHMD == NULL)
		return;
	/// for somebody asking for the default figure out the time from now to photons.
	/*	float fSecondsSinceLastVsync;
	gHMD->GetTimeSinceLastVsync(&fSecondsSinceLastVsync, NULL);

	float fDisplayFrequency = gHMD->GetFloatTrackedDeviceProperty(vr::k_unTrackedDeviceIndex_Hmd, vr::Prop_DisplayFrequency_Float);
	float fFrameDuration = 1.f / fDisplayFrequency;
	float fVsyncToPhotons = gHMD->GetFloatTrackedDeviceProperty(vr::k_unTrackedDeviceIndex_Hmd, vr::Prop_SecondsFromVsyncToPhotons_Float);

	float fPredictedSecondsFromNow = fFrameDuration - fSecondsSinceLastVsync + fVsyncToPhotons;*/

	
	
	
	vr::VRCompositor()->WaitGetPoses(gTrackedDevicePose, vr::k_unMaxTrackedDeviceCount, NULL, 0);

	m_iValidPoseCount = 0;
	m_strPoseClasses = "";
	for (int nDevice = 0; nDevice < vr::k_unMaxTrackedDeviceCount; ++nDevice)
	{
		if (gTrackedDevicePose[nDevice].bPoseIsValid)
		{
			m_iValidPoseCount++;
			m_rmat4DevicePose[nDevice] = ConvertSteamVRMatrixToMatrix42(gTrackedDevicePose[nDevice].mDeviceToAbsoluteTracking);
			if (m_rDevClassChar[nDevice] == 0)
			{
				switch (gHMD->GetTrackedDeviceClass(nDevice))
				{
				case vr::TrackedDeviceClass_Controller:        m_rDevClassChar[nDevice] = 'C'; break;
				case vr::TrackedDeviceClass_HMD:               m_rDevClassChar[nDevice] = 'H'; break;
				case vr::TrackedDeviceClass_Invalid:           m_rDevClassChar[nDevice] = 'I'; break;
				case vr::TrackedDeviceClass_GenericTracker:    m_rDevClassChar[nDevice] = 'G'; break;
				case vr::TrackedDeviceClass_TrackingReference: m_rDevClassChar[nDevice] = 'T'; break;
				default:                                       m_rDevClassChar[nDevice] = '?'; break;
				}
			}
			m_strPoseClasses += m_rDevClassChar[nDevice];
		}
	}

	if (gTrackedDevicePose[vr::k_unTrackedDeviceIndex_Hmd].bPoseIsValid)
	{
		m_mat4HMDPose = m_rmat4DevicePose[vr::k_unTrackedDeviceIndex_Hmd];
		//gM4HMDPose = ConvertGLHMatrix4ToLLMatrix4(m_mat4HMDPose);
		//gM4HMDPose.invert;
		//gluInvertMatrix(m_rmat4DevicePose[vr::k_unTrackedDeviceIndex_Hmd].m, m_mat4HMDPose.m);
		//m_mat4HMDPose.inverse();
	}
}

std::string llviewerVR::GetTrackedDeviceString(vr::IVRSystem *pHmd, vr::TrackedDeviceIndex_t unDevice, vr::TrackedDeviceProperty prop, vr::TrackedPropertyError *peError )
{
	uint32_t unRequiredBufferLen = pHmd->GetStringTrackedDeviceProperty(unDevice, prop, NULL, 0, peError);
	if (unRequiredBufferLen == 0)
		return "";

	char *pchBuffer = new char[unRequiredBufferLen];
	unRequiredBufferLen = pHmd->GetStringTrackedDeviceProperty(unDevice, prop, pchBuffer, unRequiredBufferLen, peError);
	std::string sResult = pchBuffer;
	delete[] pchBuffer;
	return sResult;
}

void llviewerVR::SetupCameras()
{
	m_mat4ProjectionLeft = GetHMDMatrixProjectionEye(vr::Eye_Left);
	//gM4eyeProjectionLeft = ConvertGLHMatrix4ToLLMatrix4(m_mat4ProjectionLeft);

	m_mat4ProjectionRight = GetHMDMatrixProjectionEye(vr::Eye_Right);
	//gM4eyeProjectionRight = ConvertGLHMatrix4ToLLMatrix4(m_mat4ProjectionRight);

	m_mat4eyePosLeft = GetHMDMatrixPoseEye(vr::Eye_Left);
	//gM4eyePosLeft = ConvertGLHMatrix4ToLLMatrix4(m_mat4eyePosLeft);
	//gM4eyePosLeft.invert();

	m_mat4eyePosRight = GetHMDMatrixPoseEye(vr::Eye_Right);
	//gM4eyePosRight = ConvertGLHMatrix4ToLLMatrix4(m_mat4eyePosRight);
	//gM4eyePosRight.invert();
}

bool llviewerVR::CreateFrameBuffer(int nWidth, int nHeight, FramebufferDesc &framebufferDesc)
{
	/*glGenFramebuffers(1, &framebufferDesc.m_nRenderFramebufferId);
	glBindFramebuffer(GL_FRAMEBUFFER, framebufferDesc.m_nRenderFramebufferId);

	glGenRenderbuffers(1, &framebufferDesc.m_nDepthBufferId);
	glBindRenderbuffer(GL_RENDERBUFFER, framebufferDesc.m_nDepthBufferId);
	glRenderbufferStorageMultisample(GL_RENDERBUFFER, 4, GL_DEPTH_COMPONENT, nWidth, nHeight);
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, framebufferDesc.m_nDepthBufferId);

	glGenTextures(1, &framebufferDesc.m_nRenderTextureId);
	glBindTexture(GL_TEXTURE_2D_MULTISAMPLE, framebufferDesc.m_nRenderTextureId);
	glTexImage2DMultisample(GL_TEXTURE_2D_MULTISAMPLE, 4, GL_RGBA8, nWidth, nHeight, true);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D_MULTISAMPLE, framebufferDesc.m_nRenderTextureId, 0);
	*/
	if (framebufferDesc.m_nResolveTextureId)
	{
		glDeleteTextures(1, &framebufferDesc.m_nResolveTextureId);
		//glDeleteFramebuffers(1, &framebufferDesc.mFBO)
	}	
	else
	{ 
		glGenFramebuffers(1, &framebufferDesc.mFBO);
		
	}
	glBindFramebuffer(GL_FRAMEBUFFER, framebufferDesc.mFBO);
	glGenTextures(1, &framebufferDesc.m_nResolveTextureId);
	glBindTexture(GL_TEXTURE_2D, framebufferDesc.m_nResolveTextureId);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, nWidth, nHeight, 0, GL_RGBA, GL_UNSIGNED_BYTE, nullptr);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, framebufferDesc.m_nResolveTextureId, 0);
	
	// check FBO status
	GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
	if (status != GL_FRAMEBUFFER_COMPLETE)
	{
		return false;
	}

	glBindFramebuffer(GL_FRAMEBUFFER, 0);

	return true;
}

void llviewerVR::vrStartup(bool is_shutdown)
{
	//static LLCachedControl<bool> vrEn(gSavedSettings, "EnableVR");
	//m_bVrEnabled = false;//gPipeline.EnableSteamVR;
	
	/*hud_textp = (LLHUDText *)LLHUDObject::addHUDObject(LLHUDObject::LL_HUD_TEXT);
	hud_textp->setZCompare(FALSE);
	LLColor4 color(1, 1, 1);
	hud_textp->setColor(color);
	LLVector3 s = LLViewerCamera::getInstance()->getAtAxis();

	hud_textp->setPositionAgent(gAgent.getPositionAgent() - s);
	std::string str("This is the hud test");
	hud_textp->setString(str);
	hud_textp->setHidden(FALSE);*/


	if (m_bVrEnabled && !is_shutdown)
	{
		if (gHMD == NULL)
		{
			gVRInitComplete = FALSE;
			vr::EVRInitError eError = vr::VRInitError_None;
			gHMD = vr::VR_Init(&eError, vr::VRApplication_Scene);
			m_strHudText="Initializing VR driver!";
			//hud_textp->setString(m_strHudText);

			if (eError != vr::VRInitError_None)
			{
				gHMD = NULL;
				char buf[1024];
				sprintf_s(buf, sizeof(buf), "\nERROR Unable to init VR runtime: %s", vr::VR_GetVRInitErrorAsEnglishDescription(eError));
				m_strHudText.append( buf);
				//return false;
			}
			else
			{
				m_strDriver = "No Driver";
				m_strDisplay = "No Display";

				m_strDriver = GetTrackedDeviceString(gHMD, vr::k_unTrackedDeviceIndex_Hmd, vr::Prop_TrackingSystemName_String);
				m_strDisplay = GetTrackedDeviceString(gHMD, vr::k_unTrackedDeviceIndex_Hmd, vr::Prop_SerialNumber_String);
				m_strHudText.append("\nDriver = ");
				m_strHudText.append(m_strDriver);
				m_strHudText.append("\nDisplay = ");
				m_strHudText.append(m_strDriver);
				m_strHudText.append("\nVR driver! Initialized");

			}

			eError = vr::VRInitError_None;
			if (gHMD != NULL)
				gRenderModels = (vr::IVRRenderModels *)vr::VR_GetGenericInterface(vr::IVRRenderModels_Version, &eError);

			if (!gRenderModels)
			{
				gHMD = NULL;
				vr::VR_Shutdown();

				char buf[1024];
				sprintf_s(buf, sizeof(buf), "\nERROR Unable to get render model interface: %s", vr::VR_GetVRInitErrorAsEnglishDescription(eError));
				m_strHudText.append(buf);
				//SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "VR_Init Failed", buf, NULL);
				//return false;
			}
			eError = vr::VRInitError_None;

			if (!vr::VRCompositor())
			{

				char buf[1024];
				sprintf_s(buf, sizeof(buf), "\nERROR No compositor interface: %s", vr::VR_GetVRInitErrorAsEnglishDescription(eError));
				m_strHudText.append(buf);
				gHMD = NULL;
				vr::VR_Shutdown();

			}
			if (gHMD != NULL && !gVRInitComplete)
			{
				gVRInitComplete = TRUE;
				vr::VRCompositor()->SetTrackingSpace(vr::TrackingUniverseSeated);
				gHMD->GetRecommendedRenderTargetSize(&m_nRenderWidth, &m_nRenderHeight);
				
				//m_nRenderHeight	=	1440;
				//m_nRenderWidth	=	1440;
				//if (leftEyeDesc.m_nResolveTextureId == NULL)
				CreateFrameBuffer(m_nRenderWidth, m_nRenderHeight, leftEyeDesc);
				//if (rightEyeDesc.m_nResolveTextureId == NULL)
				CreateFrameBuffer(m_nRenderWidth, m_nRenderHeight, rightEyeDesc);
				SetupCameras();
				//vr::VRCompositor()->ForceInterleavedReprojectionOn(true);
				//vr::VRCompositor()->SetTrackingSpace(vr::);
				//m_tTimer1.start();
				
				m_strHudText.append("\nCreating frame buffers.");
				
				
				
				
			}
			if(gVRInitComplete)
				m_strHudText.append("\nVR driver ready.\n Press TAB to enter VR mode.");
			hud_textp->setString(m_strHudText);
			m_strHudText = "";
			hud_textp->setDoFade(FALSE);
			hud_textp->setHidden(FALSE);
		}
	}
	else if (gHMD || is_shutdown)
	{
		m_bVrActive = FALSE;
		vr::VR_Shutdown();
		gHMD = NULL;
		gVRInitComplete = FALSE;
		//m_tTimer1.stop();
		//m_tTimer1.cleanupClass();
	}
	
}

bool llviewerVR::ProcessVRCamera()
{
	
	if (hud_textp == NULL)
	{
		
			
				hud_textp = (LLHUDText *)LLHUDObject::addHUDObject(LLHUDObject::LL_HUD_TEXT);
				if (hud_textp != NULL)
				{
					hud_textp->setZCompare(FALSE);
					LLColor4 color(1, 1, 1);
					hud_textp->setColor(color);
					hud_textp->setHidden(FALSE);
					hud_textp->setMaxLines(-1);

					m_strHudText.append("Press CTRL+TAB to enable or disable VR mode\n Press TAB to remove this message");
					hud_textp->setString(m_strHudText);
					m_strHudText = "";
				}
		
	}
	else
	{
		m_vdir = LLViewerCamera::getInstance()->getAtAxis();
		m_vpos = LLViewerCamera::getInstance()->getOrigin();
		LLVector3 end = m_vpos + (m_vdir)* 1.0f;
		hud_textp->setPositionAgent(end);
	}
		
	
	if (gHMD == NULL)
	{
		return FALSE;
	}
	if (m_bVrActive)//gAgentCamera.getCameraMode() == CAMERA_MODE_MOUSELOOK)
	{
		InitUI();
		//m_fNearClip = LLViewerCamera::getInstance()->getNear();
		//m_fFarClip = LLViewerCamera::getInstance()->getFar();
		LLViewerCamera::getInstance()->setNear(0.001);

		

		if (!leftEyeDesc.IsReady && !rightEyeDesc.IsReady)//Starting rendering with first (left) eye of stereo rendering
		{
			
			
			//Set the windows max size and aspect ratio to fit with the HMD.
#ifdef _WIN32
			int scrsize = GetSystemMetrics(SM_CYSCREEN);
			if (GetSystemMetrics(SM_CXSCREEN) < scrsize)
				scrsize = GetSystemMetrics(SM_CXSCREEN);
#else
    int scrsize = 1080;
#endif
			LLWindow * WI;
			WI = gViewerWindow->getWindow();
			WI->getCursorPosition(&m_MousePos);
			
			LLCoordWindow m_ScrSize;
			LLCoordWindow m_ScrSizeOld;
		
			WI->getSize(&m_ScrSizeOld);
			float mult = (float)m_nRenderWidth / (float)m_nRenderHeight;
			if (m_nRenderHeight<m_nRenderWidth)
			mult = (float)m_nRenderHeight / (float)m_nRenderWidth;
			
			m_ScrSize.mX = (scrsize*mult)*0.95;
			m_ScrSize.mY = (scrsize)*0.95;
			if (m_ScrSizeOld.mX != m_ScrSize.mX || m_ScrSizeOld.mY != m_ScrSize.mY)
			{
				m_ScrSize.set(m_ScrSize.mX, m_ScrSize.mY);
				WI->setSize(m_ScrSize);
			}
			//Constrain the cursor to the viewer window.
			if (m_MousePos.mX >= m_ScrSize.mX)
				m_MousePos.mX = m_ScrSize.mX - 1;
			else if (m_MousePos.mX < 1)
				m_MousePos.mX = 1;
			if (m_MousePos.mY >= m_ScrSize.mY)
				m_MousePos.mY = m_ScrSize.mY - 1;
			else if (m_MousePos.mY < 1)
				m_MousePos.mY = 1;

			m_iHalfWidth = m_ScrSize.mX / 2;
			m_iHalfHeight = m_ScrSize.mY / 2;
			m_iThirdWidth = m_ScrSize.mX / 3;
			m_iThirdHeight = m_ScrSize.mY / 3;
			

			//Store current camera values
			m_vdir_orig = LLViewerCamera::getInstance()->getAtAxis();
			m_vup_orig = LLViewerCamera::getInstance()->getUpAxis();
			m_vleft_orig = LLViewerCamera::getInstance()->getLeftAxis();
			m_vpos_orig = LLViewerCamera::getInstance()->getOrigin();
			
			if (!m_bEditActive)// unlock HMD's rotation input.
			{
				//convert HMD matrix in to direction vectors that work with SL
				glh::ns_float::vec4 row = m_mat4HMDPose.get_row(2);
				m_vdir.setVec(row.v[0], -row.v[2], row.v[1]);
				
				row = m_mat4HMDPose.get_row(1);
				m_vup.setVec(row.v[0], -row.v[2], row.v[1]);
				
				row = m_mat4HMDPose.get_row(0);
				m_vleft.setVec(row.v[0], -row.v[2], row.v[1]);
				
				row = m_mat4HMDPose.get_row(3);
				gHmdPos.setVec(row.v[0], -row.v[2], row.v[1]);

				if (gHmdOffsetPos.mV[VZ] == 0)
				{
					gHmdOffsetPos = gHmdPos;
				}

				LLQuaternion qCameraOrig(m_vdir_orig, m_vleft_orig, m_vup_orig);
				float r3;
				float p3;
				float y3;
				qCameraOrig.getEulerAngles(&r3, &p3, &y3);

				//convert HMD euler angles to   to quat rotation
				LLQuaternion qHMDRot(m_vdir, m_vleft, m_vup);
				float r1;
				float p1;
				float y1;
				qHMDRot.getEulerAngles(&r1, &p1, &y1);

				//make a quat of the sl camera rotation
				LLQuaternion qCameraOffset;
				qCameraOffset.setEulerAngles(r3, p3, y3 - (m_fCamRotOffset * DEG_TO_RAD));
				//Offset player camera with the HMD rotation
				qHMDRot = qHMDRot*qCameraOffset;
				gHMDQuat = qHMDRot;
				

				LLMatrix3 m3 = qHMDRot.getMatrix3();
				m_vdir = -m3.getFwdRow();
				m_vup = m3.getUpRow();
				m_vleft = m3.getLeftRow();
				m_vdir.normalize();
				m_vup.normalize();
				m_vleft.normalize();

				m_vpos = m_vpos_orig + (((gHmdPos - gHmdOffsetPos))* (qCameraOffset));
			}
			else //lock HMD's rotation input for inworld object editing purposes.
			{
				m_vdir = m_vdir_orig;
				m_vup = m_vup_orig;
				m_vleft = m_vleft_orig;
				m_vpos = m_vpos_orig;
			}

			
			if (m_iMenuIndex)
			{
				hud_textp->setString(Settings());
				LLVector3 end = m_vpos + m_vdir * 1.0f;
				hud_textp->setPositionAgent(end);
				hud_textp->setDoFade(FALSE);
				hud_textp->setHidden(FALSE);
				

				
			}
			else if (m_bDebugKeyDown)
			{
				Debug();
			}
			else
				hud_textp->setHidden(TRUE);

		}
		

		LLVector3 new_dir;
		if (m_bEditActive)// lock HMD's rotation input for inworls object editing purposes.
		{
			if (m_fEyeDistance == 0)
				LLViewerCamera::getInstance()->lookDir(m_vdir_orig, m_vup_orig);
			new_dir = (m_vleft * (m_fEyeDistance / 1000));
		}
		else
		{
			if (m_fEyeDistance == 0)
				LLViewerCamera::getInstance()->lookDir(m_vdir, m_vup);
			new_dir = (-m_vleft * (m_fEyeDistance / 1000));
		}
			
		
		if (m_fEyeDistance > 0)
		{	
			LLVector3 new_fwd_pos = m_vpos + (m_vdir * m_fFocusDistance);
			
			if (!leftEyeDesc.IsReady)//change pos for rendering the left eye texture.Move half IPD distance to the left
			{
				LLViewerCamera::getInstance()->updateCameraLocation(m_vpos + new_dir, m_vup, new_fwd_pos);
			}
			else if (!rightEyeDesc.IsReady)//change pos for rendering the right eye texture. Move full IPD distance to the right since we were on the left eye position.
			{
				LLViewerCamera::getInstance()->updateCameraLocation(m_vpos - new_dir, m_vup, new_fwd_pos);
			}
		}
		
		

	}
	return TRUE;
}

void llviewerVR::vrDisplay()
{
	if (gHMD != NULL)
	{
		if (m_bVrActive)//gAgentCamera.getCameraMode() == CAMERA_MODE_MOUSELOOK)
		{
			

			if (!leftEyeDesc.IsReady)
			{
				bx = 0;
				by = 0;
				tx = gPipeline.mScreen.getWidth();
				ty = gPipeline.mScreen.getHeight();

				m_iTextureShift = ((tx / 2) / 100)* m_fTextureShift;

				S32 halfx = tx / 2;
				S32 halfy = ty / 2;
				S32 div8x = tx / 6;
				S32 div8y = ty / 6;

				S32 thirdx = tx / 3;
				S32 thirdy = ty / 3;
				

				if (m_MousePos.mX > tx - div8x && m_MousePos.mY < div8y)//up right
				{
					m_iZoomIndex = 4;
				}
				else if (m_MousePos.mX > tx - div8x && m_MousePos.mY > ty - div8y)//down right
				{
					m_iZoomIndex = 5;
				}
				else if (m_MousePos.mX < div8x && m_MousePos.mY > ty - div8y)//down left 
				{
					m_iZoomIndex = 6;
				}
				else if (m_MousePos.mX < div8x && m_MousePos.mY < div8y)//up left
				{
					m_iZoomIndex = 7;
				}
				else if (m_MousePos.mX > tx - div8x && m_MousePos.mY > halfy - div8y && m_MousePos.mY < halfy + div8y)//right
				{
					m_iZoomIndex = 10;
				}
				else if (m_MousePos.mY > ty - div8y &&  m_MousePos.mX > halfx - div8x &&  m_MousePos.mX < halfx + div8x)//down
				{
					m_iZoomIndex = 9;
				}
				else if (m_MousePos.mY < div8y &&  m_MousePos.mX >  halfx - div8x &&  m_MousePos.mX < halfx + div8x)//up
				{
					m_iZoomIndex = 8;
				}
				else if (m_MousePos.mX <  div8x && m_MousePos.mY > halfy - div8y && m_MousePos.mY < halfy + div8y)//left
				{
					m_iZoomIndex = 11;
				}
				else if (m_MousePos.mX > halfx - div8x && m_MousePos.mX < halfx + div8x && m_MousePos.mY > halfy - div8y && m_MousePos.mY < halfy + div8y)//center
				{
					m_iZoomIndex = 0;
				}

				///Zoom in
				if (m_iZoomIndex == 0)
				{
					bx +=   m_fTextureZoom;
					by +=   m_fTextureZoom;
					tx -=   m_fTextureZoom;
					ty -=   m_fTextureZoom;
				}
				else if (m_iZoomIndex == 4)//up right
				{
					bx += thirdx;
					by += thirdy;
					tx += thirdx;
					ty += thirdy;
				}
				else if (m_iZoomIndex == 5)//down right
				{
					bx += thirdx;
					by -= thirdy;
					tx += thirdx;
					ty -= thirdy;
				}
				else if (m_iZoomIndex == 6)//down left 
				{
					bx -= thirdx;
					by -= thirdy;
					tx -= thirdx;
					ty -= thirdy;
				}
				else if (m_iZoomIndex == 7)//up left
				{
					bx -= thirdx;
					by += thirdy;
					tx -= thirdx;
					ty += thirdy;
				}
				else if (m_iZoomIndex == 8)//up 
				{
					by += thirdy;
					ty += thirdy;
				}
				else if (m_iZoomIndex == 9)//down
				{
					by -= thirdy;
					ty -= thirdy;
				}
				else if (m_iZoomIndex == 11)//left
				{
					bx -= thirdx;
					tx -= thirdx;
				}
				else if (m_iZoomIndex == 10)//right
				{
					bx += thirdx;
					tx += thirdx;
				}
			}
			glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
			glReadBuffer(GL_BACK);
		
			//if left camera was active bind left eye buffer for drawing in to
			if (!leftEyeDesc.IsReady)
			{
				glBindFramebuffer(GL_DRAW_FRAMEBUFFER, leftEyeDesc.mFBO);
				if (m_iZoomIndex)
					glClear(GL_COLOR_BUFFER_BIT);
				//leftEyeDesc.IsReady = TRUE;
				
				glBlitFramebuffer(bx, by, tx, ty, m_iTextureShift, 0, m_nRenderWidth + m_iTextureShift, m_nRenderHeight, GL_COLOR_BUFFER_BIT, GL_LINEAR);
				
			}
			if ((leftEyeDesc.IsReady && !rightEyeDesc.IsReady) || m_fEyeDistance == 0)//if right camera was active bind left eye buffer for drawing in to
			{
				glBindFramebuffer(GL_DRAW_FRAMEBUFFER, rightEyeDesc.mFBO);
				if (m_iZoomIndex)
					glClear(GL_COLOR_BUFFER_BIT);
				rightEyeDesc.IsReady = TRUE;
				glBlitFramebuffer(bx, by, tx, ty, -m_iTextureShift, 0, m_nRenderWidth - m_iTextureShift, m_nRenderHeight, GL_COLOR_BUFFER_BIT, GL_LINEAR);
			}
			if (!leftEyeDesc.IsReady)
				leftEyeDesc.IsReady = TRUE;

			//Remove bindings of read and draw buffer
			glBindFramebuffer(GL_FRAMEBUFFER, 0);

			if (leftEyeDesc.IsReady && (rightEyeDesc.IsReady || m_fEyeDistance == 0))
			{

				rightEyeDesc.IsReady = FALSE;
				leftEyeDesc.IsReady = FALSE;
				//glFlush();
				
				//vr::VRCompositor()->CompositorBringToFront();   could help with no image issues
				

				//Update HMD . !!!!!  This calls waitGetPoses() which is essential to start the rendering process in the HMD after Submit and gets the current HMD pose(rotation location matrix)
				//if you do not call that anywhere no image will be processed. 
				
				
				//submit the textures to the HMD
				lEyeTexture = { (void*)(uintptr_t)leftEyeDesc.m_nResolveTextureId, vr::TextureType_OpenGL, vr::ColorSpace_Gamma };
				eError = vr::VRCompositor()->Submit(vr::Eye_Left, &lEyeTexture, 0, (vr::EVRSubmitFlags)(vr::Submit_Default ));

				rEyeTexture = { (void*)(uintptr_t)rightEyeDesc.m_nResolveTextureId, vr::TextureType_OpenGL, vr::ColorSpace_Gamma };
				eError = vr::VRCompositor()->Submit(vr::Eye_Right, &rEyeTexture, 0, (vr::EVRSubmitFlags)(vr::Submit_Default));

				//vr::VRCompositor()->PostPresentHandoff();// Here we tell the HMD  that rendering is done and it can render the image in to the HMD
				//glFinish();
				
				gViewerWindow->getWindow()->swapBuffers();
				
				
				//glFlush();
				
				
				
				UpdateHMDMatrixPose();
				//

			}

		}





	}
	//else if (vrEnabled)
	//{
		//vrStartup();
	//}

}

void llviewerVR::ProcessVREvent(const vr::VREvent_t & event)//process vr´events 
{
	switch (event.eventType)
	{
	case vr::VREvent_TrackedDeviceActivated:
	{
		//SetupRenderModelForTrackedDevice(event.trackedDeviceIndex);
		//dprintf("Device %u attached. Setting up render model.\n", event.trackedDeviceIndex);
	}
	break;
	case vr::VREvent_TrackedDeviceDeactivated:
	{
		//dprintf("Device %u detached.\n", event.trackedDeviceIndex);
	}
	break;
	case vr::VREvent_TrackedDeviceUpdated:
	{
		//dprintf("Device %u updated.\n", event.trackedDeviceIndex);
	}
	case vr::VREvent_Quit:
	{
		m_bVrActive = FALSE;
		m_bVrEnabled = FALSE;
		gHMD = NULL;
		vr::VR_Shutdown();
		vr::VRSystem()->AcknowledgeQuit_Exiting();
	}
	break;
	}
}

void llviewerVR::agentYaw(F32 yaw_inc)  // move avatar forward backward and rotate 
{
	// Cannot steer some vehicles in mouselook if the script grabs the controls
	if (gAgentCamera.cameraMouselook()  && gSavedSettings.getBOOL("JoystickMouselookYaw"))
	{
		gAgent.rotate(-yaw_inc, gAgent.getReferenceUpVector());
		
	}
	else
	{
		if (yaw_inc < 0)
		{
			gAgent.setControlFlags(AGENT_CONTROL_YAW_POS);
		}
		else if (yaw_inc > 0)
		{
			gAgent.setControlFlags(AGENT_CONTROL_YAW_NEG);
		}

		gAgent.yaw(-yaw_inc);
	}
}

bool llviewerVR::HandleInput()// handles controller input for now  only the stick.
{

	if (gHMD == NULL || !m_bVrActive)
		return FALSE;
	bool bRet = false;

	// Process SteamVR events
	vr::VREvent_t event;
	while (gHMD->PollNextEvent(&event, sizeof(event)))
	{
		ProcessVREvent(event);
	}

	// Process SteamVR controller state
	/*for (vr::TrackedDeviceIndex_t unDevice = 0; unDevice < vr::k_unMaxTrackedDeviceCount; unDevice++)
	{
		vr::VRControllerState_t state;
		if (gHMD->GetControllerState(unDevice, &state, sizeof(state)))
		{
			m_rbShowTrackedDevice[unDevice] = state.ulButtonPressed == 0;
			if (state.unPacketNum != gPacketNum)
			{
				gPacketNum = state.unPacketNum;
				//add intensity slider here.
				if (fabs(state.rAxis[2].x) > 0.3)// +x rechts +y fwd
					agentYaw(state.rAxis[2].x / 20);
				if (state.rAxis[2].y > 0.5)// +x rechts +y fwd
					gAgent.moveAt(1, false);
				else if (state.rAxis[2].y < -0.5)// +x rechts +y fwd
					gAgent.moveAt(-1, false);
				gButton = state.ulButtonPressed;
				
				
				
				LLWindow * WI;
				WI = gViewerWindow->getWindow();
				MASK mask = gKeyboard->currentMask(TRUE);		
				//S32 width = gViewerWindow->getWorldViewWidthScaled();
				//S32 height = gViewerWindow->getWindowHeightScaled();
				S32 height = gViewerWindow->getWorldViewHeightScaled();
				LLCoordWindow size;
				size.mX = gCtrlscreen[unDevice].mX;
				//size.mY = gCtrlscreen[unDevice].mY;
				size.mY = height - gCtrlscreen[unDevice].mY;
				//gCtrlscreen[unDevice].mY = height - gCtrlscreen[unDevice].mY;
				

				if ((state.ulButtonPressed &  vr::ButtonMaskFromId(vr::k_EButton_Grip)) && !gRightClick[unDevice])
				{
					
					gRightClick[unDevice] = TRUE;
					if (gAgentCamera.getCameraMode() != CAMERA_MODE_MOUSELOOK)
					{ 
						
						WI->setCursorPosition(size);
					}
					
					//LLWindowWin32 *window_imp = (LLWindowWin32 *)GetWindowLongPtr(mAppWindowHandle, GWLP_USERDATA);
					
					gViewerWindow->handleAnyMouseClick(WI, gCtrlscreen[unDevice], mask, LLMouseHandler::CLICK_RIGHT, TRUE);
					
					
					INPUT Inputs[1] { 0 };
					Inputs[0].type = INPUT_MOUSE;
					Inputs[0].mi.dwFlags = MOUSEEVENTF_RIGHTDOWN;
					//SendInput(1, Inputs, sizeof(INPUT));
				}
				else if (gRightClick[unDevice] && !(state.ulButtonPressed &  vr::ButtonMaskFromId(vr::k_EButton_Grip)))
				{
					gRightClick[unDevice] = FALSE;

					gViewerWindow->handleAnyMouseClick(WI, gCtrlscreen[unDevice], mask, LLMouseHandler::CLICK_RIGHT, FALSE);
					INPUT Inputs[1] = { 0 };
					Inputs[0].type = INPUT_MOUSE;
					Inputs[0].mi.dwFlags = MOUSEEVENTF_RIGHTUP;
					//SendInput(1, Inputs, sizeof(INPUT));


				}
				

				if ((state.ulButtonPressed & vr::ButtonMaskFromId(vr::k_EButton_SteamVR_Trigger)) && !gLeftClick[unDevice])
				{
					if (gAgentCamera.getCameraMode() != CAMERA_MODE_MOUSELOOK)
					{
						gLeftClick[unDevice] = TRUE;
						//LLWindow * WI;
						//WI = gViewerWindow->getWindow();
						//S32 width = gViewerWindow->getWorldViewWidthScaled();
						//S32 height = gViewerWindow->getWorldViewHeightScaled();
						//LLCoordWindow size;
						//size.mX = gCtrlscreen[0].mX;
						//size.mY = height - gCtrlscreen[0].mY;
						WI->setCursorPosition(size);
					}
					INPUT Inputs[1] = { 0 };
					Inputs[0].type = INPUT_MOUSE;
					Inputs[0].mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
					SendInput(1, Inputs, sizeof(INPUT));
				}
				else if (gLeftClick[unDevice] && !(state.ulButtonPressed & vr::ButtonMaskFromId(vr::k_EButton_SteamVR_Trigger)))
				{
					gLeftClick[unDevice] = FALSE;
					INPUT Inputs[1] = { 0 };
					Inputs[0].type = INPUT_MOUSE;
					Inputs[0].mi.dwFlags = MOUSEEVENTF_LEFTUP;
					SendInput(1, Inputs, sizeof(INPUT));
				}

			}

		}
		
	}*/

	return bRet;
}

void llviewerVR::HandleKeyboard()
{
	// Don't attempt to update controllers if input is not available
	//gCtrlNum = 0;

	if (gKeyboard->getKeyDown(KEY_TAB) && !m_bVrKeyDown)
	{

		m_bVrKeyDown = TRUE;


	}
	else if (!gKeyboard->getKeyDown(KEY_TAB) && m_bVrKeyDown)
	{
		m_bVrKeyDown = FALSE;
		
		if (gKeyboard->getKeyDown(KEY_CONTROL))
		{
			if (!m_bVrEnabled)
			{
				m_bVrEnabled = TRUE;
				vrStartup(FALSE);
			}
			else
			{
				m_bVrActive = FALSE;
				m_bVrEnabled = FALSE;
				vrStartup(FALSE);
			}
				
		}
		else if (gHMD)
		{
			if (!m_bVrActive)
				m_bVrActive = TRUE;
			else
				m_bVrActive = FALSE;
			//LLViewerCamera::getInstance()->setDefaultFOV(1.8);
			gHmdOffsetPos.mV[2] = 0;
			INISaveRead(false);
			if (m_fFOV > 20)
				LLViewerCamera::getInstance()->setDefaultFOV(m_fFOV * DEG_TO_RAD);
			
			/*LLCoordWindow cpos;
			cpos.mX = m_nRenderWidth / 2;
			cpos.mY = m_nRenderHeight / 2;
			LLWindow * WI;
			WI = gViewerWindow->getWindow();
			//WI->setCursorPosition(cpos);

			INPUT Inputs[1] ;
			Inputs[0].mi.dx = m_nRenderWidth / 2;
			Inputs[0].mi.dy = m_nRenderHeight / 2;
			Inputs[0].type = INPUT_MOUSE;
			Inputs[0].mi.dwFlags = MOUSEEVENTF_MOVE;

			SendInput(1, Inputs, sizeof(INPUT));*/

		}
		else
		{
			m_strHudText = "";
			hud_textp->setString(m_strHudText);
			hud_textp->setDoFade(FALSE);
			hud_textp->setHidden(TRUE);
		}
		
	}

	if (gHMD == NULL)
		return;
	if (gKeyboard->getKeyDown(m_kEditKey) && !m_bEditKeyDown)
	{
		m_bEditKeyDown = TRUE;
		//m_iClockCount2 =  m_tTimer1.getCurrentClockCount();
	}
	else if (!gKeyboard->getKeyDown(m_kEditKey) && m_bEditKeyDown)
	{
		m_bEditKeyDown = FALSE;
		//m_iClockCount = m_tTimer1.getCurrentClockCount() - m_iClockCount2;
		/*if (m_iClockCount  > 5000000)
		{
		m_iZoomIndex++;
		if (m_iZoomIndex > 5)
		m_iZoomIndex = 0;
		}
		else*/
		if (!m_bEditActive)
			m_bEditActive = TRUE;
		else
			m_bEditActive = FALSE;
	}

	if (gKeyboard->getKeyDown(m_kDebugKey) && !m_bDebugKeyDown)
	{
		m_bDebugKeyDown = TRUE;
	}
	else if (!gKeyboard->getKeyDown(m_kDebugKey) && m_bDebugKeyDown)
	{
		m_bDebugKeyDown = FALSE;
		//m_iZoomIndex++;
		if (m_iZoomIndex > 7)
			m_iZoomIndex = 0;
	}

	if (gKeyboard->getKeyDown(m_kMenuKey) && !m_bMenuKeyDown)
	{
		m_bMenuKeyDown = TRUE;
	}
	else if (!gKeyboard->getKeyDown(m_kMenuKey) && m_bMenuKeyDown)
	{
		m_bMenuKeyDown = FALSE;
		if (m_iMenuIndex == 5)
			INISaveRead(true);

		m_iMenuIndex++;
		if (m_iMenuIndex > 5)
			m_iMenuIndex = 0;
	}
}

void llviewerVR::DrawCursors()
{
	if (!m_bVrActive)
		return;
	gUIProgram.bind();
	//glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
	//gViewerWindow->setup2DRender();
	gGL.pushMatrix();
	S32 half_width = (gViewerWindow->getWorldViewWidthScaled() / 2);
	S32 half_height = (gViewerWindow->getWorldViewHeightScaled() / 2);

	S32 wwidth = gViewerWindow->getWindowWidthScaled();
	S32 wheight = gViewerWindow->getWindowHeightScaled();

	//translatef moves 0 vector to the pos you specified so oyu can draw fron zero vector there
	gGL.translatef((F32)half_width, (F32)half_height, 0.f);
	gGL.color4fv(LLColor4::white.mV);
	//glClear(GL_DEPTH_BUFFER_BIT);
	//glDisable(GL_DEPTH_TEST);
	LLWindow * WI;
	WI = gViewerWindow->getWindow();
	LLCoordWindow   mcpos;
	WI->getCursorPosition(&mcpos);
	LLCoordGL mpos = gViewerWindow->getCurrentMouse();

	for (vr::TrackedDeviceIndex_t unTrackedDevice = vr::k_unTrackedDeviceIndex_Hmd + 1; unTrackedDevice < vr::k_unMaxTrackedDeviceCount; ++unTrackedDevice)
	{
		if (gCtrlscreen[unTrackedDevice].mX > -1)
		{

			gl_circle_2d(gCtrlscreen[unTrackedDevice].mX - half_width, gCtrlscreen[unTrackedDevice].mY - half_height + gCursorDiff, half_width / 200, 8, TRUE);
		}

	}

	if (gAgentCamera.getCameraMode() != CAMERA_MODE_MOUSELOOK)
	{
		LLColor4 cl;
		cl = LLColor4::black.mV;

		S32 mx = mpos.mX - half_width;
		S32 my = mpos.mY - (half_height);
		if (mpos.mX < 0 || mpos.mX > wwidth)
			mx = half_width;
		if (mpos.mY < 0 || mpos.mY > wheight)
			my = half_height;

		gl_triangle_2d(mx, my, mx + 8, my - 15, mx + 15, my - 8, cl, TRUE);
		cl = LLColor4::white.mV;
		gl_triangle_2d(mx+2, my-2, mx + 9, my - 13, mx + 12, my - 8, cl, TRUE);
	}

	//gl_circle_2d(mpos.mX - half_width, mpos.mY - (half_height)  /*+ gVR.gCursorDiff)*/, half_width / 200, 8, TRUE);

	//glEnable(GL_DEPTH_TEST);
	gGL.popMatrix();
	gUIProgram.unbind();
	stop_glerror();
}

void llviewerVR::RenderControllerAxes()
{
	// Don't attempt to update controllers if input is not available
	//gCtrlNum = 0;
	
	HandleKeyboard();
	
	if (gHMD == NULL)
		return;
	HandleInput();
	if (!gHMD->IsInputAvailable() || !m_bVrActive)
		return;

	//std::vector<float> vertdataarray;
	//m_uiControllerVertcount = 0;
	//m_iTrackedControllerCount = 0;
	
	
	for (vr::TrackedDeviceIndex_t unTrackedDevice = vr::k_unTrackedDeviceIndex_Hmd + 1; unTrackedDevice < vr::k_unMaxTrackedDeviceCount; ++unTrackedDevice)
	{
		gCtrlscreen[unTrackedDevice].set(-1, -1);
		if (!gHMD->IsTrackedDeviceConnected(unTrackedDevice))
			continue;

		if (gHMD->GetTrackedDeviceClass(unTrackedDevice) != vr::TrackedDeviceClass_Controller)
			continue;

		m_iTrackedControllerCount += 1;

		if (!gTrackedDevicePose[unTrackedDevice].bPoseIsValid)
			continue;

		//Count the controllers
		
		glh::matrix4f mat = m_rmat4DevicePose[unTrackedDevice];
		
		//glh::vec4f center; 
		//mat.mult_matrix_vec(glh::vec4f(0, 0, 0, 1),center) ;
		
		LLVector3 pos = m_vpos; // LLViewerCamera::getInstance()->getOrigin();
		LLVector3 dir;
		LLVector3 up;
		LLVector3 left;
		
		glh::ns_float::vec4 row = mat.get_row(2);
		dir.setVec(row.v[0], -row.v[2], row.v[1]);

		row = mat.get_row(1);
		up.setVec(row.v[0], -row.v[2], row.v[1]);

		row = mat.get_row(0);
		left.setVec(row.v[0], -row.v[2], row.v[1]);

		row = mat.get_row(3);
		gCtrlOrigin[unTrackedDevice].setVec(row.v[0], -row.v[2], row.v[1]);

		LLQuaternion q1(dir, left, up);
		
		//get modified camera rot in euler angles
		float r2;
		float p2;
		float y2;
		q1.getEulerAngles(&r2, &p2, &y2);

		LLQuaternion qCameraOrig(m_vdir_orig, m_vleft_orig, m_vup_orig);
		float r3;
		float p3;
		float y3;
		qCameraOrig.getEulerAngles(&r3, &p3, &y3);


		//make a quat of yaw rot of the HMD camera
		//LLQuaternion q2;
		//q2.setEulerAngles(0, p2, y2 + (m_fCamRotOffset * DEG_TO_RAD));
		LLQuaternion q3;
		q3.setEulerAngles(0, 0, y3 - (m_fCamRotOffset * DEG_TO_RAD));

		//change the controller rotation according to the HMD facing direction
		q1 = (q1)*q3;

		//grab the forward vector from the quat matrix
		LLMatrix3 m3 = q1.getMatrix3();
		dir = m3.getFwdRow();

		//up = m3.getUpRow();
		//left = m3.getLeftRow();
		dir.normalize();
		//up.normalize();
		//left.normalize();
		//get position of the controller
		gCtrlOrigin[unTrackedDevice] -= gHmdPos;
		gCtrlOrigin[unTrackedDevice] = m_vpos + gCtrlOrigin[unTrackedDevice] * q3;
		//project 10 meter line  in the direction the controller is facing
		gCtrlPos[unTrackedDevice] = gCtrlOrigin[unTrackedDevice]  - (dir * 10.0f);

		//translate the fwd vector line to screen coords
		posToScreen(gCtrlPos[unTrackedDevice], gCtrlscreen[unTrackedDevice], FALSE);
	
		//adjust the pos so it fits with the actual mouse cursor pos
		S32 height = gViewerWindow->getWorldViewHeightScaled();
		gCursorDiff= gViewerWindow->getWindowHeightScaled();
		gCursorDiff = gCursorDiff - height;
		gCtrlscreen[unTrackedDevice].mY -= gCursorDiff;
		
	


	
		//draw the controller lines in world  ( make tham nicer ;>)
		LLGLSUIDefault gls_ui;
		gGL.getTexUnit(0)->unbind(LLTexUnit::TT_TEXTURE);
		LLVector3 v = gCurrentCameraPos;	
		// Some coordinate axes
		glClear(GL_DEPTH_BUFFER_BIT);
		glDisable(GL_DEPTH_TEST);
		gGL.pushMatrix();
		gGL.translatef(v.mV[VX], v.mV[VY], v.mV[VZ]);
		gGL.begin(LLRender::LINES);
		gGL.color3f(1.0f, 0.0f, 0.0f);   // i direction = X-Axis = red
		gGL.vertex3f(gCtrlOrigin[unTrackedDevice].mV[VX], gCtrlOrigin[unTrackedDevice].mV[VY], gCtrlOrigin[unTrackedDevice].mV[VZ]);
		gGL.vertex3f(gCtrlPos[unTrackedDevice].mV[VX], gCtrlPos[unTrackedDevice].mV[VY], gCtrlPos[unTrackedDevice].mV[VZ]);
		gGL.end();
		gGL.popMatrix();
		glEnable(GL_DEPTH_TEST);

		//EVRControllerAxisType
		//read the input from the available controllers
		vr::VRControllerState_t state;
		if (gHMD->GetControllerState(unTrackedDevice, &state, sizeof(state)))
		{
			m_rbShowTrackedDevice[unTrackedDevice] = state.ulButtonPressed == 0;
			if (1)// state.unPacketNum != gPacketNum)
			{
				//if(LLFloaterCamera::inFreeCameraMode())
				gPacketNum = state.unPacketNum;
				//Get the joystick hat state of the controller and move the avatar.. (Figure out how to map it tpo vive and oculus)
				//add movement intensity slider here.
				if (fabs(state.rAxis[2].x) > 0.5 && gHMD->GetControllerRoleForTrackedDeviceIndex(unTrackedDevice))// +x rechts +y fwd
				{
					if (LLFloaterCamera::inFreeCameraMode())
					{
						m_fCamRotOffset += 0.5;
						if (m_fCamRotOffset > 360)
							m_fCamRotOffset = 0;

					}
					else
					{
						m_fCamRotOffset = 90;
						agentYaw(state.rAxis[2].x / 40);

					}
							
				}
				else if (state.rAxis[2].y > 0.5)// +y forward
				{
					if (LLFloaterCamera::inFreeCameraMode())
					{
						
						m_fCamPosOffset += 0.2;
					}
					else
					{
						gAgent.moveAt(1, false);
						m_fCamPosOffset = 0;
					}
						
				}
					
				else if (state.rAxis[2].y < -0.5)// -y back
				{
					if (LLFloaterCamera::inFreeCameraMode())
					{
						
						m_fCamPosOffset -= 0.2;
					}
					else
					{
						gAgent.moveAt(-1, false);
						m_fCamPosOffset = 0;
					}
						
				}
					
				
				
				gButton = state.ulButtonPressed;
				LLWindow * WI;
				WI = gViewerWindow->getWindow();
				//MASK mask = gKeyboard->currentMask(TRUE);
				

				S32 width = gViewerWindow->getWorldViewWidthScaled();
				//S32 height = gViewerWindow->getWindowHeightScaled();
				S32 height = gViewerWindow->getWorldViewHeightScaled();
				LLCoordWindow cpos;
				cpos.mX = gCtrlscreen[unTrackedDevice].mX;
				//size.mY = gCtrlscreen[unDevice].mY;
				cpos.mY = height - gCtrlscreen[unTrackedDevice].mY;
				//gCtrlscreen[unDevice].mY = height - gCtrlscreen[unDevice].mY;

				//LLCoordWindow *  mcpos;
				//WI->getCursorPosition(mcpos);

				//Emulate mouse clicks with the controllers trigger and grip buttons

				if ((state.ulButtonPressed &  vr::ButtonMaskFromId(vr::k_EButton_Grip)) && !gRightClick[unTrackedDevice])
				{

					gRightClick[unTrackedDevice] = TRUE;
					if (gAgentCamera.getCameraMode() != CAMERA_MODE_MOUSELOOK)
					{

						WI->setCursorPosition(cpos);
					}

					//LLWindowWin32 *window_imp = (LLWindowWin32 *)GetWindowLongPtr(mAppWindowHandle, GWLP_USERDATA);

					//gViewerWindow->handleAnyMouseClick(WI, gCtrlscreen[unTrackedDevice], mask, LLMouseHandler::CLICK_RIGHT, TRUE);


#ifdef _WIN32
					INPUT Inputs[1] { 0 };
					Inputs[0].type = INPUT_MOUSE;
					Inputs[0].mi.dwFlags = MOUSEEVENTF_RIGHTDOWN;
					SendInput(1, Inputs, sizeof(INPUT));
#else
#endif
				}
				else if (gRightClick[unTrackedDevice] && !(state.ulButtonPressed &  vr::ButtonMaskFromId(vr::k_EButton_Grip)))
				{
					gRightClick[unTrackedDevice] = FALSE;

					//gViewerWindow->handleAnyMouseClick(WI, gCtrlscreen[unTrackedDevice], mask, LLMouseHandler::CLICK_RIGHT, FALSE);
#ifdef _WIN32
					INPUT Inputs[1] = { 0 };
					Inputs[0].type = INPUT_MOUSE;
					Inputs[0].mi.dwFlags = MOUSEEVENTF_RIGHTUP;
					SendInput(1, Inputs, sizeof(INPUT));
#else
#endif
				}


				if ((state.ulButtonPressed & vr::ButtonMaskFromId(vr::k_EButton_SteamVR_Trigger)) && !gLeftClick[unTrackedDevice])
				{
					gLeftClick[unTrackedDevice] = TRUE;
					if (gAgentCamera.getCameraMode() != CAMERA_MODE_MOUSELOOK)
					{
						
						//LLWindow * WI;
						//WI = gViewerWindow->getWindow();
						//S32 width = gViewerWindow->getWorldViewWidthScaled();
						//S32 height = gViewerWindow->getWorldViewHeightScaled();
						//LLCoordWindow size;
						//size.mX = gCtrlscreen[0].mX;
						//size.mY = height - gCtrlscreen[0].mY;
						WI->setCursorPosition(cpos);
					}
#ifdef _WIN32
					INPUT Inputs[1] = { 0 };
					Inputs[0].type = INPUT_MOUSE;
					Inputs[0].mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
					SendInput(1, Inputs, sizeof(INPUT));
#else
#endif
				}
				else if (gLeftClick[unTrackedDevice] && !(state.ulButtonPressed & vr::ButtonMaskFromId(vr::k_EButton_SteamVR_Trigger)))
				{
					gLeftClick[unTrackedDevice] = FALSE;
#ifdef _WIN32
					INPUT Inputs[1] = { 0 };
					Inputs[0].type = INPUT_MOUSE;
					Inputs[0].mi.dwFlags = MOUSEEVENTF_LEFTUP;
					SendInput(1, Inputs, sizeof(INPUT));
#else
#endif
				}

				if(gAgentCamera.getCameraMode() != CAMERA_MODE_MOUSELOOK && gLeftClick[unTrackedDevice] && cpos.mX>-1 && cpos.mX < width  && cpos.mY >-1 && cpos.mY < height)
				{
					
					WI->setCursorPosition(cpos);
				}

			}

		}
	}
	
}

BOOL llviewerVR::posToScreen(const LLVector3 &pos_agent, LLCoordGL &out_point, const BOOL clamp) const
{
	//BOOL in_front = TRUE;
	GLdouble	x, y, z;			// object's window coords, GL-style

	/*LLVector3 dir_to_point = pos_agent - LLViewerCamera::getInstance()->getOrigin();
	dir_to_point /= dir_to_point.magVec();

	if (dir_to_point * LLCoordFrame::getAtAxis() < 0.f)
	{
		if (clamp)
		{
			return FALSE;
		}
		else
		{
			in_front = FALSE;
		}
	}
	*/
	LLRect world_view_rect = gViewerWindow->getWorldViewRectRaw();
	
	//LLRect world_view_rect = gViewerWindow->handleAnyMouseClick;
	
	S32	viewport[4];
	viewport[0] = world_view_rect.mLeft;
	viewport[1] = world_view_rect.mBottom;
	viewport[2] = world_view_rect.getWidth();
	viewport[3] = world_view_rect.getHeight();

	F64 mdlv[16];
	F64 proj[16];

	for (U32 i = 0; i < 16; i++)
	{
		mdlv[i] = (F64)gGLModelView[i];
		proj[i] = (F64)gGLProjection[i];
	}

	if (GL_TRUE == gluProject(pos_agent.mV[VX], pos_agent.mV[VY], pos_agent.mV[VZ],
		mdlv, proj, (GLint*)viewport,
		&x, &y, &z))
	{
		// convert screen coordinates to virtual UI coordinates
		x /= gViewerWindow->getDisplayScale().mV[VX];
		y /= gViewerWindow->getDisplayScale().mV[VY];

		// should now have the x,y coords of grab_point in screen space
		LLRect world_rect = gViewerWindow->getWorldViewRectScaled();

		// convert to pixel coordinates
		S32 int_x = lltrunc(x);
		S32 int_y = lltrunc(y);

		out_point.mX = int_x;
		out_point.mY = int_y;

		BOOL valid = TRUE;
		return valid;
		/*
		if (clamp)
		{
			if (int_x < world_rect.mLeft)
			{
				out_point.mX = world_rect.mLeft;
				valid = FALSE;
			}
			else if (int_x > world_rect.mRight)
			{
				out_point.mX = world_rect.mRight;
				valid = FALSE;
			}
			else
			{
				out_point.mX = int_x;
			}

			if (int_y < world_rect.mBottom)
			{
				out_point.mY = world_rect.mBottom;
				valid = FALSE;
			}
			else if (int_y > world_rect.mTop)
			{
				out_point.mY = world_rect.mTop;
				valid = FALSE;
			}
			else
			{
				out_point.mY = int_y;
			}
			return valid;
		}
		else
		{
			out_point.mX = int_x;
			out_point.mY = int_y;

			if (int_x < world_rect.mLeft)
			{
				valid = FALSE;
			}
			else if (int_x > world_rect.mRight)
			{
				valid = FALSE;
			}
			if (int_y < world_rect.mBottom)
			{
				valid = FALSE;
			}
			else if (int_y > world_rect.mTop)
			{
				valid = FALSE;
			}

			return in_front && valid;
		}*/
	}
	else
	{
		return FALSE;
	}
}

void  llviewerVR::buttonCallbackLeft()
{
	if (m_pCamStack)
	{
		
		m_fCamRotOffset -= 5;
		if (m_fCamRotOffset > 360)
			m_fCamRotOffset = 0;

	}
}

void  llviewerVR::buttonCallbackRight()
{
	if (m_pCamStack)
	{
		m_fCamRotOffset += 5;
		if (m_fCamRotOffset > 360)
			m_fCamRotOffset = 0;
		
		LLRect rc;
		rc.setCenterAndSize(80, 80, 160, 80);
		m_pCamStack->setRect(rc);
		if (m_pCamera_floater)
		{
			rc = m_pCamera_floater->getRect();
			rc.setCenterAndSize(rc.getCenterX(), rc.getCenterY(), 200, 120);
			//m_pCamera_floater->setRect(rc);
			m_pCamera_floater->handleReshape(rc, TRUE);
		}
		

	}
}

std::string llviewerVR::Settings()
{
	std::string str;
	std::wstring wstr;
	std::string sep1 = "\n\xe2\x96\x88\xe2\x96\x88\xe2\x96\x88 ";
	std::string sep2 = " \xe2\x96\x88\xe2\x96\x88\xe2\x96\x88";
	

	//str = INISaveRead(false);
	//str.append("\n");	
	if (m_iMenuIndex == 1)
	{
		m_fEyeDistance=Modify(m_fEyeDistance, 1.0, 0, 200);
		str.append(sep1);
		str.append("IPD = ");
		str.append(std::to_string(m_fEyeDistance));
		str.append(sep2);
		str.append("\nFocus Distance = ");
		str.append(std::to_string(m_fFocusDistance));
		str.append("\nTexture Shift = ");
		str.append(std::to_string(m_fTextureShift));
		str.append("\nTexture Zoom = ");
		str.append(std::to_string(m_fTextureZoom));
		str.append("\nFOV = ");
		str.append(std::to_string(m_fFOV));
		str.append("\n \nDistance between left and right camera.\nUsually the same as the IPD of your HMD.\nIf objects appear too small or too big try other values. ");
	}
	else if (m_iMenuIndex == 2)
	{
		m_fFocusDistance=Modify(m_fFocusDistance, 0.25, 0.5, 10);
		str.append("IPD = ");
		str.append(std::to_string(m_fEyeDistance));
		str.append(sep1);
		str.append("Focus Distance = ");
		str.append(std::to_string(m_fFocusDistance));
		str.append(sep2);
		str.append("\nTexture shift = ");
		str.append(std::to_string(m_fTextureShift));
		str.append("\nTexture Zoom = ");
		str.append(std::to_string(m_fTextureZoom));
		str.append("\nFOV = ");
		str.append(std::to_string(m_fFOV));

		str.append("\n \nFocus distance of the cameras in meters");
	}
	else if (m_iMenuIndex == 3)
	{
		m_fTextureShift = Modify(m_fTextureShift, 0.5, -100, 100);
		str.append("IPD = ");
		str.append(std::to_string(m_fEyeDistance));
		str.append("\nFocus Distance = ");
		str.append(std::to_string(m_fFocusDistance));
		str.append(sep1);
		str.append("Texture shift = ");
		str.append(std::to_string(m_fTextureShift));
		str.append(sep2);
		str.append("\nTexture Zoom = ");
		str.append(std::to_string(m_fTextureZoom));
		str.append("\nFOV = ");
		str.append(std::to_string(m_fFOV));
		str.append("\n \nApplies a texture shift in case your HMD's focus point is not in the center of the texture.");
	}
	else if (m_iMenuIndex == 4)
	{
		m_fTextureZoom = Modify(m_fTextureZoom, 1, -200, 200);
		str.append("IPD = ");
		str.append(std::to_string(m_fEyeDistance));
		str.append("\nFocus Distance = ");
		str.append(std::to_string(m_fFocusDistance));
		str.append("\nTexture shift = ");
		str.append(std::to_string(m_fTextureShift));
		str.append(sep1);
		str.append("Texture Zoom = ");
		str.append(std::to_string(m_fTextureZoom));
		str.append(sep2);
		str.append("\nFOV = ");
		str.append(std::to_string(m_fFOV));
		str.append("\n \nZooms the view in or out. It may help with wide FOV HMD's like Pimax.\n Zoom in reduces quality. Zoom out increases quality\nWhen this value is changed FOV must also be adjusted.");
	}
	else if (m_iMenuIndex == 5)
	{
		m_fFOV = Modify(m_fFOV, 0.5, 50, 175);
		LLViewerCamera::getInstance()->setDefaultFOV(m_fFOV * DEG_TO_RAD);
		str.append("IPD = ");
		str.append(std::to_string(m_fEyeDistance));
		str.append("\nFocus Distance = ");
		str.append(std::to_string(m_fFocusDistance));
		str.append("\nTexture shift = ");
		str.append(std::to_string(m_fTextureShift));
		str.append("\nTexture Zoom = ");
		str.append(std::to_string(m_fTextureZoom));
		str.append(sep1);
		str.append("FOV = ");
		str.append(std::to_string(m_fFOV));
		str.append(sep2);
		str.append("\n \nField of view in degree adjustment. Usually 100 degree is good.\n It should be adjusted when texture zoom is changed.");
	}
	return str;
}

F32 llviewerVR::Modify(F32 val, F32 step, F32 min, F32 max)
{
	if (gKeyboard->getKeyDown(m_kPlusKey) && (!m_bPlusKeyDown || gKeyboard->getKeyElapsedTime(m_kPlusKey) >1))
	{
		m_bPlusKeyDown = TRUE;
		val += step;
		if (val > max)
			val = max;
		return val;
	}
	else if (!gKeyboard->getKeyDown(m_kPlusKey) && m_bPlusKeyDown)
	{
		m_bPlusKeyDown = FALSE;
		/*val += step;
		if (val > max)
			val = max;
		return val;*/

	}
	if (gKeyboard->getKeyDown(m_kMinusKey) && !m_bMinusKeyDown)
	{
		m_bMinusKeyDown = TRUE;
	}
	else if (!gKeyboard->getKeyDown(m_kMinusKey) && m_bMinusKeyDown)
	{
		m_bMinusKeyDown = FALSE;
		val -= step;
		if (val < min)
			val = min;
		return val;
	}
	return val;
}

std::string llviewerVR::INISaveRead(bool save)
{
	std::string path = gDirUtilp->getOSUserAppDir()+"\\vrconfig.ini";
	std::string ret;
	ret.append(path);
	ret.append("\n");
	std::string line;
	std::fstream file;
	if (!save)
	{
		file.open(path, std::ios_base::in);

		if (file.is_open())
		{
			while (getline(file, line, ','))
			{
				if (line == "EyeDistance")
				{
					//ret.append(line.append("|"));
					getline(file, line, ',');
					m_fEyeDistance = std::stof(line);
				}
				else if (line == "FocusDistance")
				{
					//ret.append(line.append("|"));
					getline(file, line, ',');
					m_fFocusDistance = std::stof(line);
				}
				else if (line == "TextureShift")
				{
					//ret.append(line.append("|"));
					getline(file, line, ',');
					m_fTextureShift = std::stof(line);
				}
				else if (line == "TextureZoom")
				{
					//ret.append(line.append("|"));
					getline(file, line, ',');
					m_fTextureZoom = std::stof(line);
				}
				else if (line == "FieldOfView")
				{
					//ret.append(line.append("|"));
					getline(file, line, ',');
					m_fFOV = std::stof(line);
				}

			}
			file.close();
		}
		else
			ret.append("\n file not open!!!\n");
	}
	else
	{
		file.open(path, std::ios_base::out);
		std::string s;
		s.append("EyeDistance");
		s.append(",");
		s.append(std::to_string(m_fEyeDistance));
		s.append(",");

		s.append("FocusDistance");
		s.append(",");
		s.append(std::to_string(m_fFocusDistance));
		s.append(",");

		s.append("TextureShift");
		s.append(",");
		s.append(std::to_string(m_fTextureShift));
		s.append(",");

		s.append("TextureZoom");
		s.append(",");
		s.append(std::to_string(m_fTextureZoom));
		s.append(",");

		s.append("FieldOfView");
		s.append(",");
		s.append(std::to_string(m_fFOV));
		
		if (file.is_open())
		{
			file << s.c_str();
			file.close();
		}

	}
	return ret;

}

void llviewerVR::Debug()
{
	LLWindow * WI;
	WI = gViewerWindow->getWindow();
	LLCoordWindow mpos;
	WI->getCursorPosition(&mpos);
	LLCoordGL mcpos = gViewerWindow->getCurrentMouse();
	LLVector3 voffset = gHmdPos - gHmdOffsetPos;
	std::string str;
	str.append(" Cam Pos \n< ");
	str.append(std::to_string(m_vpos.mV[VX]));
	str.append(" , ");
	str.append(std::to_string(m_vpos.mV[VY]));
	str.append(" , ");
	str.append(std::to_string(m_vpos.mV[VZ]));
	str.append(" > ");
	str.append("\n HMD Pos offset - hmd \n< ");
	str.append(std::to_string(voffset.mV[VX]));
	str.append(" , ");
	str.append(std::to_string(voffset.mV[VY]));
	str.append(" , ");
	str.append(std::to_string(voffset.mV[VZ]));
	str.append(" > ");
	str.append("\n HMD Pos offset \n< ");
	str.append(std::to_string(gHmdOffsetPos.mV[VX]));
	str.append(" , ");
	str.append(std::to_string(gHmdOffsetPos.mV[VY]));
	str.append(" , ");
	str.append(std::to_string(gHmdOffsetPos.mV[VZ]));
	str.append(" > ");
	str.append("\n HMD Pos  \n< ");
	str.append(std::to_string(gHmdPos.mV[VX]));
	str.append(" , ");
	str.append(std::to_string(gHmdPos.mV[VY]));
	str.append(" , ");
	str.append(std::to_string(gHmdPos.mV[VZ]));
	str.append(" > ");
	/*
	str.append("\nPointe Pos\n< ");
	str.append(std::to_string(gCtrlPos[0].mV[VX]));
	str.append(" , ");
	str.append(std::to_string(gCtrlPos[0].mV[VY]));
	str.append(" , ");
	str.append(std::to_string(gCtrlPos[0].mV[VZ]));
	str.append(" > ");

	str.append("\nPoint Origin\n< ");
	str.append(std::to_string(gCtrlOrigin[0].mV[VX]));
	str.append(" , ");
	str.append(std::to_string(gCtrlOrigin[0].mV[VY]));
	str.append(" , ");
	str.append(std::to_string(gCtrlOrigin[0].mV[VZ]));
	str.append(" > ");*/

	str.append("\n Zoom Index");
	str.append(std::to_string(m_iZoomIndex));

	str.append("\n MCoord X=");
	str.append(std::to_string(mpos.mX));
	str.append(" Y=");
	str.append(std::to_string(mpos.mY));

	str.append("\n MCoord X=");
	str.append(std::to_string(mcpos.mX));
	str.append(" Y=");
	str.append(std::to_string(mcpos.mY));
	str.append("\n Mview X=");
	str.append(std::to_string(m_MousePos.mX));
	str.append(" Y=");
	str.append(std::to_string(m_MousePos.mY));

	str.append("\n Coord1 X=");
	str.append(std::to_string(gCtrlscreen[1].mX));
	str.append(" Y=");
	str.append(std::to_string(gCtrlscreen[1].mY));
	str.append("\n Rheight=");
	str.append(std::to_string(m_nRenderHeight));
	str.append("\n Rwidth=");
	str.append(std::to_string(m_nRenderWidth));
	str.append("\n Button=");
	str.append(std::to_string(gButton));

	str.append("\n Cam Rot Offset in DEG =");
	str.append(std::to_string(m_fCamRotOffset));

	str.append("\nL+R Camera Distance in mm\n");
	str.append(std::to_string(m_fEyeDistance));
	str.append("\nCurrent FOV \n");
	str.append(std::to_string(LLViewerCamera::getInstance()->getDefaultFOV()));
	//str.append("\n LastGL ERR=");
	//str.append(std::to_string(err));


	hud_textp->setString(str);
	LLVector3 end = m_vpos + (m_vdir)* 1.0f;
	hud_textp->setPositionAgent(end);
	hud_textp->setDoFade(FALSE);
	hud_textp->setHidden(FALSE);
}

void llviewerVR::InitUI()
{
		if (!m_pCamButtonLeft)
		{
			/*LLPanel* panelp = NULL;
			panelp=LLPanel::createFactoryPanel("vr_controlls");

			panelp->setRect(rc);
			LLColor4 color(1, 1, 1);
			panelp->setOrigin(700, 700);
			panelp->setColor(color);
			panelp->setVisible(TRUE);
			panelp->setEnabled(TRUE);*/
			LLRect rc;
			rc.setCenterAndSize(500, 500, 200, 200);


			m_pCamera_floater = LLFloaterReg::findTypedInstance<LLFloaterCamera>("camera");
			if (m_pCamera_floater)
			{
				LLStringExplicit lb("keks");
				//LLRect rc;
				//LLButton  *m_pButton1;
				LLButton  *m_pButton;
				for (int i = 0; i < 2; i++)
				{

					LLButton::Params p;
					if (i == 0)
					{
						p.name("rot_left");
						p.label("<<");
					}
					else
					{
						p.name("rot_right");
						p.label(">>");
					}


					m_pButton = LLUICtrlFactory::create<LLButton>(p);


					m_pCamera_floater->addChild(m_pButton);
					//panelp->addChild(m_pButton);
					if (i == 0)
						rc.setCenterAndSize(20, 20, 30, 20);
					else
						rc.setCenterAndSize(50, 20, 30, 20);
					m_pButton->setRect(rc);
					m_pButton->setVisible(TRUE);
					m_pButton->setEnabled(TRUE);
					if (i == 0)
						m_pCamButtonLeft = m_pButton;
					else
						m_pCamButtonRight = m_pButton;
				}
				m_pCamButtonLeft->setCommitCallback(boost::bind(&llviewerVR::buttonCallbackLeft, this));
				m_pCamButtonRight->setCommitCallback(boost::bind(&llviewerVR::buttonCallbackRight, this));

				/*m_pButton1 = m_pCamera_floater->findChild<LLButton>("rot_left");
				//lb.assign("<");
				if (m_pButton1)
				{
				m_pButton1->setLabel(LLStringExplicit("<"));
				m_pButton1->setCommitCallback(boost::bind(&llviewerVR::buttonsCallback, this));
				}*/


				m_pCamStack = m_pCamera_floater->findChild<LLView>("camera_view_layout_stack");


				//m_pCamera_floater->getChildList();
				//m_pButton1->
			}
		}
}
