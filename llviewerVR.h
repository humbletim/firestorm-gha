#pragma once

#include <openvr.h>
#include "llhudtext.h"
#include "llgl.h"
#include "string.h"
#include "llfloater.h"
#include "llfloatercamera.h"
//#include "control.h"
//#include "llviewercamera.h"
//#include "llagentcamera.h"
//#include "pipeline.h"
//#include "llagent.h"
//#include "llviewerwindow.h"


class llviewerVR
{
public:
	vr::IVRSystem *gHMD = 0;
	vr::IVRCompositor* gCompositor = 0;
	vr::IVRRenderModels * gRenderModels = 0;
	std::string gStrDriver;
	std::string gStrDisplay;
	vr::TrackedDevicePose_t gTrackedDevicePose[vr::k_unMaxTrackedDeviceCount];
	vr::VRCompositorError eError = vr::VRCompositorError_None;
	vr::Texture_t lEyeTexture;
	vr::Texture_t rEyeTexture;

	U32 bx = 0;
	U32 by = 0;
	U32 tx = 0;
	U32 ty = 0;

	KEY	m_kEditKey;
	KEY	m_kDebugKey;
	KEY	m_kMenuKey;
	KEY	m_kPlusKey;
	KEY	m_kMinusKey;

	bool m_bVrEnabled = 0;
	
	bool m_bVrActive = 0;
	bool m_bVrKeyDown = 0;
	
	bool m_bEditKeyDown = 0;
	bool m_bEditActive = 0;
	
	bool m_bDebugKeyDown = 0;

	bool m_bMenuKeyDown = 0;
	bool m_bPlusKeyDown = 0;
	bool m_bMinusKeyDown = 0;


	bool isRenderingLeftEye = 0;
	bool gVRInitComplete = 0;


	S32 m_iTextureShift = 0;

	struct FramebufferDesc
	{
		GLuint m_nDepthBufferId;
		GLuint m_nRenderTextureId;
		GLuint m_nRenderFramebufferId;
		GLuint m_nResolveTextureId;
		GLuint mFBO;
		GLuint IsReady;
	};
	FramebufferDesc leftEyeDesc;
	FramebufferDesc rightEyeDesc;
	U32 m_nRenderWidth;
	U32 m_nRenderHeight;
	S32 m_iTrackedControllerCount;
	S32 m_iTrackedControllerCount_Last;
	S32 m_iValidPoseCount;
	S32 m_iValidPoseCount_Last;
	S32 m_iZoomIndex = 0;
	U64 m_iClockCount;
	U64 m_iClockCount2;
	LLTimer m_tTimer1;
	F32 m_fCamRotOffset = 90;
	F32 m_fCamPosOffset = 0;

	LLVector3 m_vdir_orig;
	LLVector3 m_vup_orig;
	LLVector3 m_vleft_orig;
	LLVector3 m_vpos_orig;

	LLVector3 m_vdir;
	LLVector3 m_vup;
	LLVector3 m_vleft;
	LLVector3 m_vpos;
	LLButton  *m_pCamButtonLeft = 0;
	LLButton  *m_pCamButtonRight = 0;
	LLButton  *m_pCamButtonChat = 0;
	LLButton  *m_pCamButtonPref = 0;
	LLFloaterCamera	*m_pCamera_floater = 0;
	LLView	*m_pCamStack = 0;

	

	LLCoordWindow m_MousePos;
	LLCoordWindow m_ScrSize;
	S32 m_iHalfWidth;
	S32 m_iHalfHeight;
	S32 m_iThirdWidth;
	S32 m_iThirdHeight;
	
	S32 m_iMenuIndex;
	F32 m_fEyeDistance;
	F32 m_fFocusDistance;
	F32 m_fTextureShift;
	F32 m_fFOV;
	F32 m_fTextureZoom;

	//controller axes
//	int m_iTrackedControllerCount;
//	int m_iTrackedControllerCount_Last;
	unsigned int m_uiControllerVertcount;
	//vr::TrackedDevicePose_t m_rTrackedDevicePose[vr::k_unMaxTrackedDeviceCount];

	float m_fNearClip;
	float m_fFarClip;

	std::string m_strPoseClasses;
	std::string m_strDriver;
	std::string m_strDisplay;

	glh::matrix4f m_mat4HMDPose;
	glh::matrix4f  m_rmat4DevicePose[vr::k_unMaxTrackedDeviceCount];
	glh::matrix4f m_mat4eyePosLeft;
	glh::matrix4f m_mat4eyePosRight;

	glh::matrix4f m_mat4ProjectionCenter;
	glh::matrix4f m_mat4ProjectionLeft;
	glh::matrix4f m_mat4ProjectionRight;
	char m_rDevClassChar[vr::k_unMaxTrackedDeviceCount];


	glh::matrix4f ConvertSteamVRMatrixToMatrix4(const vr::HmdMatrix34_t &matPose);
	glh::matrix4f GetHMDMatrixProjectionEye(vr::Hmd_Eye nEye);
	glh::matrix4f GetHMDMatrixPoseEye(vr::Hmd_Eye nEye);
	glh::matrix4f GetCurrentViewProjectionMatrix(vr::Hmd_Eye nEye);

	glh::matrix4f ConvertSteamVRMatrixToMatrix42(const vr::HmdMatrix34_t &matPose);

	vr::HmdQuaternion_t GetRotation(vr::HmdMatrix34_t matrix);
	LLMatrix4 ConvertGLHMatrix4ToLLMatrix4(glh::matrix4f m);


	std::string MatrixToStr(glh::matrix4f mat, std::string name);
	std::string MatrixToStrLL(glh::matrix4f mat, std::string name);
	bool gluInvertMatrix(const float m[16], float invOut[16]);
	glh::ns_float::vec3 m_nPos;


	LLVector3 gHMDAxes;
	LLVector3 gCurrentCameraPos;
	vr::HmdVector3_t gHMDFwd;
	LLQuaternion gHMDQuat;
	LLQuaternion gCtrlQuat[2];
	LLVector3 gHmdPos;
	LLVector3 gHmdOffsetPos;

	LLVector3 gCtrlPos[vr::k_unMaxTrackedDeviceCount];
	LLVector3 gCtrlOrigin[vr::k_unMaxTrackedDeviceCount];
	//uint32_t  gCtrlNum;
	LLCoordGL gCtrlscreen[vr::k_unMaxTrackedDeviceCount];

	LLMatrix4 gM4HMDPose;
	LLMatrix4 gM4eyePosLeft;
	LLMatrix4 gM4eyeProjectionLeft;
	LLMatrix4 gM4eyePosRight;
	LLMatrix4 gM4eyeProjectionRight;
	LLHUDText *hud_textp;
	std::string m_strHudText;
	bool	m_bHudTextUpdated=FALSE;

	bool gRightClick[vr::k_unMaxTrackedDeviceCount];
	bool gLeftClick[vr::k_unMaxTrackedDeviceCount];
	bool gLeftTouchpad = FALSE;
	S32 gCursorDiff;
	uint64_t gPreviousButtonMask;
	
	uint64_t gButton;

	bool m_rbShowTrackedDevice[vr::k_unMaxTrackedDeviceCount];
	uint32_t gPacketNum = 0;

	void UpdateHMDMatrixPose();
	//std::string GetTrackedDeviceString(vr::IVRSystem *pHmd, vr::TrackedDeviceIndex_t unDevice, vr::TrackedDeviceProperty prop, vr::TrackedPropertyError *peError = NULL);
	void SetupCameras();
	bool CreateFrameBuffer(int nWidth, int nHeight, FramebufferDesc &framebufferDesc);
	void vrStartup(bool is_shutdown);
	void vrDisplay();
	bool HandleInput();
	void DrawCursors();
	void ProcessVREvent(const vr::VREvent_t & event);
	void agentYaw(F32 yaw_inc);
	bool ProcessVRCamera();
	std::string GetTrackedDeviceString(vr::IVRSystem *pHmd, vr::TrackedDeviceIndex_t unDevice, vr::TrackedDeviceProperty prop, vr::TrackedPropertyError *peError = NULL);
	void RenderControllerAxes();
	BOOL posToScreen(const LLVector3 &pos_agent, LLCoordGL &out_point, const BOOL clamp) const;
	void buttonCallbackLeft();
	void buttonCallbackRight();
	std::string Settings();
	F32 Modify(F32 val, F32 step, F32 min, F32 max);
	std::string INISaveRead(bool save = false);
	void HandleKeyboard();
	void Debug();
	void InitUI();

	
	llviewerVR();

	~llviewerVR();
};

