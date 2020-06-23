/** 
 * @file vrprefs.h
 * @brief VR preferences access panel for toolbar (Based on Quickprefs)
 *
 * $LicenseInfo:firstyear=2011&license=viewerlgpl$
 * Phoenix Firestorm Viewer Source Code
 * Copyright (C) 2011, WoLf Loonie @ Second Life
 * Copyright (C) 2013, Zi Ree @ Second Life
 * Copyright (C) 2013, Ansariel Hiller @ Second Life
 * Copyright (C) 2020, humbletim @ github.com/humbletim/firestorm-gha
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation;
 * version 2.1 of the License only.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 * 
 * Linden Research, Inc., 945 Battery Street, San Francisco, CA  94111  USA
 * http://www.firestormviewer.org
 * $/LicenseInfo$
 */

#ifndef VRPREFS_H
#define VRPREFS_H

#include "lltransientfloatermgr.h"

class LLCheckBoxCtrl;
class LLComboBox;
class LLLayoutPanel;
class LLLayoutStack;
class LLLineEditor;
class LLMultiSliderCtrl;
class LLSlider;
class LLSliderCtrl;
class VRSlider;
class VRSliderCtrl;
class LLSpinCtrl;
class VRSpinCtrl;
class LLTextBox;

class FloaterVRPrefs : public LLFloater, public LLTransientFloater
{
	friend class LLFloaterReg;

public:
	FloaterVRPrefs(const LLSD& key);
	~FloaterVRPrefs();

public:
	/*virtual*/ BOOL postBuild();
	virtual void onOpen(const LLSD& key);

  /*virtual*/ LLTransientFloaterMgr::ETransientGroup getGroup() { return LLTransientFloaterMgr::GLOBAL; }

private:
	LLButton*			mBtnResetDefaults;
	
	// Restore Quickprefs Defaults
	void onClickRestoreDefaults();
	void loadSavedSettingsFromFile(const std::string& settings_path);
	void callbackRestoreDefaults(const LLSD& notification, const LLSD& response);

public:
	virtual void onClose(bool app_quitting);

protected:
	enum ControlType
	{
		ControlTypeCheckbox = 0,
		ControlTypeText = 1,
		ControlTypeSpinner = 2,
		ControlTypeSlider = 3,
		ControlTypeRadio = 4,
		ControlTypeColor3 = 5,
		ControlTypeColor4 = 6,

		ControlTypeVRCheckbox = 100,
		ControlTypeVRText = 101,
		ControlTypeVRSpinner = 102,
		ControlTypeVRSlider = 103,
		ControlTypeVRRadio = 104,

		ControlTypeVRLabel= 201,
		ControlTypeVRButton = 204,
	};

	struct ControlEntry
	{
		LLPanel* panel;
		LLUICtrl* widget;
		LLTextBox* label_textbox;
		std::string label;
		ControlType type;
		BOOL integer;
		F32 min_value;
		F32 max_value;
		F32 increment;
		LLSD value;		// used temporary during updateControls()
	};

	// XUI definition of a control entry in vr_preferences.xml
	struct VRPrefsXMLEntry : public LLInitParam::Block<VRPrefsXMLEntry>
	{
		Mandatory<std::string>	control_name;
		Mandatory<std::string>	label;
		Optional<std::string>	translation_id;
		Mandatory<U32>			control_type;
		Mandatory<BOOL>			integer;
		Mandatory<F32>			min_value;	// "min" is frowned upon by a braindead windows include
		Mandatory<F32>			max_value;	// "max" see "min"
		Mandatory<F32>			increment;

		VRPrefsXMLEntry();
	};

	// overall XUI container in vr_preferences.xml
	struct VRPrefsXML : public LLInitParam::Block<VRPrefsXML>
	{
		Multiple<VRPrefsXMLEntry> entries;

		VRPrefsXML();
	};

	// internal list of user defined controls to display
	typedef std::map<std::string,ControlEntry> control_list_t;
	control_list_t mControlsList;

	// order of the controls on the user interface
	std::list<std::string> mControlsOrder;
	// list of layout_panel slots to put our options in
	std::list<LLLayoutPanel*> mOrderingSlots;

	// pointer to the layout_stack where the controls will be inserted
	LLLayoutStack* mOptionsStack;

	// currently selected for editing
	std::string mSelectedControl;

	// editor control widgets
	LLLineEditor* mControlLabelEdit;
	LLComboBox* mControlNameCombo;
	LLComboBox* mControlTypeCombo;
	LLCheckBoxCtrl* mControlIntegerCheckbox;
	LLSpinCtrl* mControlMinSpinner;
	LLSpinCtrl* mControlMaxSpinner;
	LLSpinCtrl* mControlIncrementSpinner;

	// returns the path to the vr_preferences.xml file. in save mode it will
	// always return the user_settings path, if not in save mode, it will return
	// the app_settings path in case the user_settings path does not (yet) exist
	std::string getSettingsPath(bool save_mode);

	// adds a new control and returns a pointer to the chosen widget
	LLUICtrl* addControl(const std::string& controlName, const std::string& controlLabel, LLView* slot = NULL, ControlType type = ControlTypeRadio, BOOL integer = FALSE, F32 min_value = -1000000.0f, F32 max_value = 1000000.0f, F32 increment = 0.0f);
	// removes a control
	void removeControl(const std::string& controlName, bool remove_slot = true);
	// updates a single control
	void updateControl(const std::string& controlName, ControlEntry& entry);

	// make this control the currently selected one
	void selectControl(std::string controlName);

	// toggles edit mode
	void onDoubleClickLabel(LLUICtrl* ctrl, void* userdata);	// userdata is the associated panel
	// selects a control in edit mode
	void onClickLabel(LLUICtrl* ctrl, void* userdata);			// userdata is the associated panel

	// will save settings when leaving edit mode
	void onEditModeChanged();
	// updates the control when a value in the edit panel was changed by the user
	void onValuesChanged();

	void onAddNewClicked();
	void onRemoveClicked(LLUICtrl* ctrl, void* userdata);		// userdata is the associated panel
	void onAlphaChanged(LLUICtrl* ctrl, void* userdata);		// userdata is the associated color swatch
	void onMoveUpClicked();
	void onMoveDownClicked();

	// swaps two controls, used for move up and down
	void swapControls(const std::string& control1, const std::string& control2);

	bool hasControl( std::string const &aName ) const
	{ return mControlsList.end() != mControlsList.find( aName ); }

};
#endif // VRPREFS_H
