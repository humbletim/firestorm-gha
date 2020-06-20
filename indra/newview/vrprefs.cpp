/** 
 * @file VRPrefs.cpp
 * @brief VR preferences access panel for right tool bar
 * (based on original Quick preferences)
 *
 * $LicenseInfo:firstyear=2011&license=viewerlgpl$
 * Phoenix Firestorm Viewer Source Code
 * Copyright (C) 2011, WoLf Loonie @ Second Life
 * Copyright (C) 2013, Zi Ree @ Second Life
 * Copyright (C) 2013, Ansariel Hiller @ Second Life
 * Copyright (C) 2013, Cinder Biscuits @ Me too
 * Copyright (C) 2020, github.com/humbletim
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

#include "lltrans.h"
#include "llapp.h"
#include "vrprefs.h"

#include "fscommon.h"
#include "llagent.h"
#include "llappviewer.h"
#include "llcheckboxctrl.h"
#include "llcolorswatch.h"
#include "llcombobox.h"
#include "llcubemap.h"
#include "llf32uictrl.h"
#include "llfeaturemanager.h"
//#include "llfloaterpreference.h" // for LLAvatarComplexityControls
#include "llfloaterreg.h"
#include "lllayoutstack.h"
#include "llmultisliderctrl.h"
#include "llnotificationsutil.h"
#include "llsliderctrl.h"
#include "llspinctrl.h"
#include "lltoolbarview.h"
#include "llviewercontrol.h"

#include <boost/foreach.hpp>

FloaterVRPrefs::VRPrefsXML::VRPrefsXML()
:	entries("entries")
{}

FloaterVRPrefs::VRPrefsXMLEntry::VRPrefsXMLEntry()
:	control_name("control_name"),
	label("label"),
	translation_id("translation_id"),
	control_type("control_type"),
	integer("integer"),
	min_value("min"),		// "min" is frowned upon by a braindead windows include
	max_value("max"),		// "max" see "min"
	increment("increment")
{}
// </FS:Zi>

FloaterVRPrefs::FloaterVRPrefs(const LLSD& key) :	LLFloater(key)  
{
	gSavedSettings.declareBOOL("VRPrefsEditMode", FALSE, "VRPrefsEditMode", LLControlVariable::ePersist::PERSIST_NO);

	if (!FSCommon::isLegacySkin())
	{
    LLTransientFloaterMgr::getInstance()->addControlView(this);
    LLTransientFloater::init(this);
	}
}

FloaterVRPrefs::~FloaterVRPrefs()
{
	if (!FSCommon::isLegacySkin())
	{
		LLTransientFloaterMgr::getInstance()->removeControlView(this);
	}
}

void FloaterVRPrefs::onOpen(const LLSD& key)
{
	gSavedSettings.setBOOL("VRPrefsEditMode", FALSE);

	// Scan widgets and reapply control variables because some control types
	// (LLSliderCtrl for example) don't update their GUI when hidden
	control_list_t::iterator it;
	for (it = mControlsList.begin(); it != mControlsList.end(); ++it)
	{
		const ControlEntry& entry = it->second;

		LLUICtrl* current_widget = entry.widget;
		if (!current_widget)
		{
			LL_WARNS() << "missing widget for control " << it->first << LL_ENDL;
			continue;
		}

		LLControlVariable* var = current_widget->getControlVariable();
		if (var)
		{
			current_widget->setValue(var->getValue());
		}
	}

}


BOOL FloaterVRPrefs::postBuild()
{
	mBtnResetDefaults = getChild<LLButton>("Restore_Btn");

  getChild<LLButton>("Restore_Btn")->setCommitCallback(boost::bind(&FloaterVRPrefs::onClickRestoreDefaults, this));
  gSavedSettings.getControl("VRPrefsEditMode")->getSignal()->connect(boost::bind(&FloaterVRPrefs::onEditModeChanged, this));	// <FS:Zi> Dynamic Quickprefs
  // <FS:Zi> Dynamic quick prefs

	// find the layout_stack to insert the controls into
	mOptionsStack = getChild<LLLayoutStack>("options_stack");

	// get the path to the user defined or default vr preferences settings
	loadSavedSettingsFromFile(getSettingsPath(false));
	
	// get edit widget pointers
	mControlLabelEdit = getChild<LLLineEditor>("label_edit");
	mControlNameCombo = getChild<LLComboBox>("control_name_combo");
	mControlTypeCombo = getChild<LLComboBox>("control_type_combo_box");
	mControlIntegerCheckbox = getChild<LLCheckBoxCtrl>("control_integer_checkbox");
	mControlMinSpinner = getChild<LLSpinCtrl>("control_min_edit");
	mControlMaxSpinner = getChild<LLSpinCtrl>("control_max_edit");
	mControlIncrementSpinner = getChild<LLSpinCtrl>("control_increment_edit");

	// wire up callbacks for changed values
	mControlLabelEdit->setCommitCallback(boost::bind(&FloaterVRPrefs::onValuesChanged, this));
	mControlNameCombo->setCommitCallback(boost::bind(&FloaterVRPrefs::onValuesChanged, this));
	mControlTypeCombo->setCommitCallback(boost::bind(&FloaterVRPrefs::onValuesChanged, this));
	mControlIntegerCheckbox->setCommitCallback(boost::bind(&FloaterVRPrefs::onValuesChanged, this));
	mControlMinSpinner->setCommitCallback(boost::bind(&FloaterVRPrefs::onValuesChanged, this));
	mControlMaxSpinner->setCommitCallback(boost::bind(&FloaterVRPrefs::onValuesChanged, this));
	mControlIncrementSpinner->setCommitCallback(boost::bind(&FloaterVRPrefs::onValuesChanged, this));

	// wire up ordering and adding buttons
	getChild<LLButton>("move_up_button")->setCommitCallback(boost::bind(&FloaterVRPrefs::onMoveUpClicked, this));
	getChild<LLButton>("move_down_button")->setCommitCallback(boost::bind(&FloaterVRPrefs::onMoveDownClicked, this));
	getChild<LLButton>("add_new_button")->setCommitCallback(boost::bind(&FloaterVRPrefs::onAddNewClicked, this));

  // functor to add debug settings to the editor dropdown
	struct f : public LLControlGroup::ApplyFunctor
	{
		LLComboBox* combo;
		f(LLComboBox* c) : combo(c) {}
		virtual void apply(const std::string& name, LLControlVariable* control)
		{
			// do not add things that are hidden in the debug settings floater
			if (!control->isHiddenFromSettingsEditor())
			{
				// don't add floater positions, sizes or visibility values
				if (name.find("floater_") != 0)
				{
					(*combo).addSimpleElement(name);
				}
			}
		}
	} func(mControlNameCombo);

	// add global and per account settings to the dropdown
	gSavedSettings.applyToAll(&func);
	gSavedPerAccountSettings.applyToAll(&func);
	mControlNameCombo->sortByName();
  // </FS:Zi>

	return LLFloater::postBuild();
}

void FloaterVRPrefs::loadSavedSettingsFromFile(const std::string& settings_path)
{
	VRPrefsXML xml;
	LLXMLNodePtr root;
	
	LL_WARNS() << "vrprefs: " << settings_path << LL_ENDL;
	if (!LLXMLNode::parseFile(settings_path, root, NULL))
	{
		LL_WARNS() << "Unable to load vr preferences from file: " << settings_path << LL_ENDL;
	}
	else if (!root->hasName("vrprefs"))
	{
		LL_WARNS() << settings_path << " is not a valid vr preferences definition file" << LL_ENDL;
	}
	else
	{
		// Parse the vr preferences settings
		LLXUIParser parser;
		parser.readXUI(root, xml, settings_path);
		
		if (!xml.validateBlock())
		{
			LL_WARNS() << "Unable to validate vr preferences from file: " << settings_path << LL_ENDL;
		}
		else
		{
			bool save_settings = false;

			// add the elements from the XML file to the internal list of controls
			BOOST_FOREACH(const VRPrefsXMLEntry& xml_entry, xml.entries)
			{
				// get the label
				std::string label = xml_entry.label;

				if (xml_entry.translation_id.isProvided())
				{
					// replace label with translated version, if available
					LLTrans::findString(label, xml_entry.translation_id);
				}

				// // Convert old RenderAvatarMaxVisible setting to IndirectMaxNonImpostors
				// if (xml_entry.control_name.getValue() != "RenderAvatarMaxVisible")
				{
					U32 type = xml_entry.control_type;
					addControl(
						xml_entry.control_name,
						label,
						NULL,
						(ControlType)type,
						xml_entry.integer,
						xml_entry.min_value,
						xml_entry.max_value,
						xml_entry.increment
						);
				
					// put it at the bottom of the ordering stack
					mControlsOrder.push_back(xml_entry.control_name);
				}
			}

			if (save_settings)
			{
				// Saves settings
				onEditModeChanged();
			}
		}
	}
}


// <FS:Zi> Dynamic vr prefs
std::string FloaterVRPrefs::getSettingsPath(bool save_mode)
{
	// get the settings file name
	std::string settings_file = LLAppViewer::instance()->getSettingsFilename("Default", "VRPreferences");
	// expand to user defined path
	std::string settings_path = gDirUtilp->getExpandedFilename(LL_PATH_USER_SETTINGS, settings_file);

	// if not in save mode, and the file was not found, use the default path
	if (!save_mode && !LLFile::isfile(settings_path))
	{
		settings_path = gDirUtilp->getExpandedFilename(LL_PATH_APP_SETTINGS, settings_file);
	}
	return settings_path;
}

void FloaterVRPrefs::updateControl(const std::string& controlName, ControlEntry& entry)
{
	// rename the panel to contain the control's name, for identification later
	entry.panel->setName(controlName);

	// build a list of all possible control widget types
	std::map<ControlType, std::string> typeMap;
	std::map<ControlType, std::string>::iterator it;

	typeMap[ControlTypeCheckbox]	= "option_checkbox_control";
	typeMap[ControlTypeText]		= "option_text_control";
	typeMap[ControlTypeSpinner]		= "option_spinner_control";
	typeMap[ControlTypeSlider]		= "option_slider_control";
	typeMap[ControlTypeRadio]		= "option_radio_control";
	typeMap[ControlTypeColor3]		= "option_color3_control";
  typeMap[ControlTypeColor4]		= "option_color4_control";

	// hide all widget types except for the one the user wants
	LLUICtrl* widget;
	for (it = typeMap.begin(); it != typeMap.end(); ++it)
	{
		if (entry.type != it->first)
		{
			widget = entry.panel->getChild<LLUICtrl>(it->second);

			if (widget)
			{
				// dummy to disable old control
				widget->setControlName("VRPrefsEditMode");
				widget->setVisible(FALSE);
				widget->setEnabled(FALSE);
			}
		}
	}

	// get the widget type the user wanted from the panel
	widget = entry.panel->getChild<LLUICtrl>(typeMap[entry.type]);

	// use 3 decimal places by default
	S32 decimals = 3;

	// save pointer to the widget in our internal list
	entry.widget = widget;

	// add the settings control to the widget and enable/show it
	widget->setControlName(controlName);
	widget->setVisible(TRUE);
	widget->setEnabled(TRUE);

	// if no increment is given, try to guess a good number
	if (entry.increment == 0.0f)
	{
		// finer grained for sliders
		if (entry.type == ControlTypeSlider)
		{
			entry.increment = (entry.max_value - entry.min_value) / 100.0f;
		}
		// a little less for spinners
		else if (entry.type == ControlTypeSpinner)
		{
			entry.increment = (entry.max_value - entry.min_value) / 20.0f;
		}
	}

	// if it's an integer entry, round the numbers
	if (entry.integer)
	{
		entry.min_value = ll_round(entry.min_value);
		entry.max_value = ll_round(entry.max_value);

		// recalculate increment
		entry.increment = ll_round(entry.increment);
		if (entry.increment == 0.f)
		{
			entry.increment = 1.f;
		}

		// no decimal places for integers
		decimals = 0;
	}

	// set up values for special case control widget types
	LLUICtrl* alpha_widget = entry.panel->getChild<LLUICtrl>("option_color_alpha_control");
	alpha_widget->setVisible(FALSE);

	// sadly, using LLF32UICtrl does not work properly, so we have to use a branch
	// for each floating point type
	if (entry.type == ControlTypeSpinner)
	{
		LLSpinCtrl* spinner = (LLSpinCtrl*)widget;
		spinner->setPrecision(decimals);
		spinner->setMinValue(entry.min_value);
		spinner->setMaxValue(entry.max_value);
		spinner->setIncrement(entry.increment);
	}
	else if (entry.type == ControlTypeSlider)
	{
		LLSliderCtrl* slider = (LLSliderCtrl*)widget;
		slider->setPrecision(decimals);
		slider->setMinValue(entry.min_value);
		slider->setMaxValue(entry.max_value);
		slider->setIncrement(entry.increment);
	}
	else if (entry.type == ControlTypeColor4)
	{
		LLColorSwatchCtrl* color_widget = (LLColorSwatchCtrl*)widget;
		alpha_widget->setVisible(TRUE);
		alpha_widget->setValue(color_widget->get().mV[VALPHA]);
	}

	// reuse a previously created text label if possible
	LLTextBox* label_textbox = entry.label_textbox;
	// if the text label is not known yet, this is a brand new control panel
	if (!label_textbox)
	{
		// otherwise, get the pointer to the new label
		label_textbox = entry.panel->getChild<LLTextBox>("option_label");

		// add double click and single click callbacks on the text label
		label_textbox->setDoubleClickCallback(boost::bind(&FloaterVRPrefs::onDoubleClickLabel, this, _1, entry.panel));
		label_textbox->setMouseUpCallback(boost::bind(&FloaterVRPrefs::onClickLabel, this, _1, entry.panel));

		// since this is a new control, wire up the remove button signal, too
		LLButton* remove_button = entry.panel->getChild<LLButton>("remove_button");
		remove_button->setCommitCallback(boost::bind(&FloaterVRPrefs::onRemoveClicked, this, _1, entry.panel));

		// and the commit signal for the alpha value in a color4 control
		alpha_widget->setCommitCallback(boost::bind(&FloaterVRPrefs::onAlphaChanged, this, _1, widget));

		// save the text label pointer in the internal list
		entry.label_textbox = label_textbox;
	}
	// set the value(visible text) for the text label
	label_textbox->setValue(entry.label + ":");

	// get the named control variable from global or per account settings
	LLControlVariable* var = gSavedSettings.getControl(controlName);
	if (!var)
	{
		var = gSavedPerAccountSettings.getControl(controlName);
	}

	// if we found the control, set up the chosen widget to use it
	if (var)
	{
		widget->setValue(var->getValue());
		widget->setToolTip(var->getComment());
		label_textbox->setToolTip(var->getComment());
	}
	else
	{
		LL_WARNS() << "Could not find control variable " << controlName << LL_ENDL;
	}
}

LLUICtrl* FloaterVRPrefs::addControl(const std::string& controlName, const std::string& controlLabel, LLView* slot, ControlType type, BOOL integer, F32 min_value, F32 max_value, F32 increment)
{
	// create a new controls panel
	LLLayoutPanel* panel = LLUICtrlFactory::createFromFile<LLLayoutPanel>("panel_vrprefs_item.xml", NULL, LLLayoutStack::child_registry_t::instance());
	if (!panel)
	{
		LL_WARNS() << "could not add panel" << LL_ENDL;
		return NULL;
	}

	// sanity checks
	if (max_value < min_value)
	{
		max_value = min_value;
	}

	// 0.0 will make updateControl calculate the increment itself
	if (increment < 0.0f)
	{
		increment = 0.0f;
	}

	// create a new internal entry for this control
	ControlEntry newControl;
	newControl.panel = panel->getChild<LLPanel>("option_ordering_panel");
	newControl.widget = NULL;
	newControl.label_textbox = NULL;
	newControl.label = controlLabel;
	newControl.type = type;
	newControl.integer = integer;
	newControl.min_value = min_value;
	newControl.max_value = max_value;
	newControl.increment = increment;

	// update the new control
	updateControl(controlName, newControl);

	// add the control to the internal list
	mControlsList[controlName] = newControl;

	// if we have a slot already, reparent our new ordering panel and delete the old layout_panel
	if (slot)
	{
		// add the ordering panel to the slot
		slot->addChild(newControl.panel);
		// make sure the panel moves to the top left corner
		newControl.panel->setOrigin(0, 0);
		// resize it to make it fill the slot
		newControl.panel->reshape(slot->getRect().getWidth(), slot->getRect().getHeight());
		// remove the old layout panel from memory
		delete panel;
	}
	// otherwise create a new slot
	else
	{
		// add a new layout_panel to the stack
		mOptionsStack->addPanel(panel, LLLayoutStack::NO_ANIMATE);
		// add the panel to the list of ordering slots
		mOrderingSlots.push_back(panel);
		// make the floater fit the newly added control panel
		reshape(getRect().getWidth(), getRect().getHeight() + panel->getRect().getHeight());
		// show the panel
		panel->setVisible(TRUE);
	}

	// hide the border
	newControl.panel->setBorderVisible(FALSE);

	return newControl.widget;
}

void FloaterVRPrefs::removeControl(const std::string& controlName, bool remove_slot)
{
	// find the control panel to remove
	const control_list_t::iterator it = mControlsList.find(controlName);
	if (it == mControlsList.end())
	{
		LL_WARNS() << "Couldn't find control entry " << controlName << LL_ENDL;
		return;
	}

	// get a pointer to the panel to remove
	LLPanel* panel = it->second.panel;
	// remember the panel's height because it will be deleted by removeChild() later
	S32 height = panel->getRect().getHeight();

	// remove the panel from the internal list
	mControlsList.erase(it);

	// get a pointer to the layout slot used
	LLLayoutPanel* slot = (LLLayoutPanel*)panel->getParent();
	// remove the panel from the slot
	slot->removeChild(panel);
	// clear the panel from memory
	delete panel;

	// remove the layout_panel if desired
	if (remove_slot)
	{
		// remove the slot from our list
		mOrderingSlots.remove(slot);
		// and delete it from the user interface stack
		mOptionsStack->removeChild(slot);

		// make the floater shrink to its new size
		reshape(getRect().getWidth(), getRect().getHeight() - height);
	}
}

void FloaterVRPrefs::selectControl(std::string controlName)
{
	// remove previously selected marker, if any
	if (!mSelectedControl.empty() && hasControl(mSelectedControl))
	{
		mControlsList[mSelectedControl].panel->setBorderVisible(FALSE);
	}

	// save the currently selected name in a volatile settings control to
	// enable/disable the editor widgets
	mSelectedControl = controlName;
	gSavedSettings.setString("VRPrefsSelectedControl", controlName);

	if (mSelectedControl.size() && !hasControl(mSelectedControl))
	{
		mSelectedControl = "";
		return;
	}

	// if we are not in edit mode, we can stop here
	if (!gSavedSettings.getBOOL("VRPrefsEditMode"))
	{
		return;
	}

	// select the topmost entry in the name dropdown, in case we don't find the name
	mControlNameCombo->selectNthItem(0);

	// assume we don't need the min/max/increment/integer widgets by default
	BOOL enable_floating_point = FALSE;

	// if actually a selection is present, set up the editor widgets
	if (!mSelectedControl.empty())
	{
		// draw the new selection border
		mControlsList[mSelectedControl].panel->setBorderVisible(TRUE);

		// set up editor values
		mControlLabelEdit->setValue(LLSD(mControlsList[mSelectedControl].label));
		mControlNameCombo->setValue(LLSD(mSelectedControl));
		mControlTypeCombo->setValue(mControlsList[mSelectedControl].type);
		mControlIntegerCheckbox->setValue(LLSD(mControlsList[mSelectedControl].integer));
		mControlMinSpinner->setValue(LLSD(mControlsList[mSelectedControl].min_value));
		mControlMaxSpinner->setValue(LLSD(mControlsList[mSelectedControl].max_value));
		mControlIncrementSpinner->setValue(LLSD(mControlsList[mSelectedControl].increment));

		// special handling to enable min/max/integer/increment widgets
		switch (mControlsList[mSelectedControl].type)
		{
			// enable floating point widgets for these types
			case ControlTypeSpinner:	// fall through
			case ControlTypeSlider:		// fall through
			{
				enable_floating_point = TRUE;

				// assume we have floating point widgets
				mControlIncrementSpinner->setIncrement(0.1f);
				// use 3 decimal places by default
				S32 decimals = 3;
				// unless we have an integer control
				if (mControlsList[mSelectedControl].integer)
				{
					decimals = 0;
					mControlIncrementSpinner->setIncrement(1.0f);
				}
				// set up floating point widgets
				mControlMinSpinner->setPrecision(decimals);
				mControlMaxSpinner->setPrecision(decimals);
				mControlIncrementSpinner->setPrecision(decimals);
				break;
			}
			// the rest will not need them
			default:
			{
			}
		}
	}

	// enable/disable floating point widgets
	mControlMinSpinner->setEnabled(enable_floating_point);
	mControlMaxSpinner->setEnabled(enable_floating_point);
	mControlIntegerCheckbox->setEnabled(enable_floating_point);
	mControlIncrementSpinner->setEnabled(enable_floating_point);
}

void FloaterVRPrefs::onClickLabel(LLUICtrl* ctrl, void* userdata)
{
	// don't do anything when we are not in edit mode
	if (!gSavedSettings.getBOOL("VRPrefsEditMode"))
	{
		return;
	}
	// get the associated panel from the submitted userdata
	LLUICtrl* panel = (LLUICtrl*)userdata;
	// select the clicked control, identified by its name
	selectControl(panel->getName());
}

void FloaterVRPrefs::onDoubleClickLabel(LLUICtrl* ctrl, void* userdata)
{
	// toggle edit mode
	BOOL edit_mode = !gSavedSettings.getBOOL("VRPrefsEditMode");
	gSavedSettings.setBOOL("VRPrefsEditMode", edit_mode);

	// select the double clicked control if we toggled edit on
	if (edit_mode)
	{
		// get the associated widget from the submitted userdata
		LLUICtrl* panel = (LLUICtrl*)userdata;
		selectControl(panel->getName());
	}
}

void FloaterVRPrefs::onEditModeChanged()
{
	// if edit mode was enabled, stop here
	if (gSavedSettings.getBOOL("VRPrefsEditMode"))
	{
		return;
	}

	// deselect the current control
	selectControl("");

	VRPrefsXML xml;
	std::string settings_path = getSettingsPath(true);

	// loop through the list of controls, in the displayed order
	std::list<std::string>::iterator it;
	for (it = mControlsOrder.begin(); it != mControlsOrder.end(); ++it)
	{
		const ControlEntry& entry = mControlsList[*it];
		VRPrefsXMLEntry xml_entry;

		// add control values to the XML entry
		xml_entry.control_name = *it;
		xml_entry.label = entry.label;
		xml_entry.control_type = (U32)entry.type;
		xml_entry.integer = entry.integer;
		xml_entry.min_value = entry.min_value;
		xml_entry.max_value = entry.max_value;
		xml_entry.increment = entry.increment;

		// add the XML entry to the overall XML container
		xml.entries.add(xml_entry);
	}

	// Serialize the parameter tree
	LLXMLNodePtr output_node = new LLXMLNode("vrprefs", false);
	LLXUIParser parser;
	parser.writeXUI(output_node, xml);

	// Write the resulting XML to file
	if (!output_node->isNull())
	{
		LLFILE* fp = LLFile::fopen(settings_path, "w");
		if (fp)
		{
			LLXMLNode::writeHeaderToFile(fp);
			output_node->writeToFile(fp);
			fclose(fp);
		}
	}
}

void FloaterVRPrefs::onValuesChanged()
{
	// safety, do nothing if we are not in edit mode
	if (!gSavedSettings.getBOOL("VRPrefsEditMode"))
	{
		return;
	}

	// don't crash when we try to update values without having a control selected
	if (mSelectedControl.empty())
	{
		return;
	}

	// remember the current and possibly new control names
	std::string old_control_name = mSelectedControl;
	std::string new_control_name = mControlNameCombo->getValue().asString();

	// if we changed the control's variable, rebuild the user interface
	if (!new_control_name.empty() && old_control_name != new_control_name)
	{
		if (mControlsList.find(new_control_name) != mControlsList.end())
		{
			LL_WARNS() << "Selected control has already been added" << LL_ENDL;
			LLNotificationsUtil::add("QuickPrefsDuplicateControl");
			return;
		}

		// remember the old control parameters so we can restore them later
		ControlEntry old_parameters = mControlsList[mSelectedControl];
		// disable selection so the border doesn't cause a crash
		selectControl("");
		// rename the old ordering entry
		std::list<std::string>::iterator it;
		for (it = mControlsOrder.begin(); it != mControlsOrder.end(); ++it)
		{
			if (*it == old_control_name)
			{
				*it = new_control_name;
				break;
			}
		}

		// remember the old slot
		LLView* slot = old_parameters.panel->getParent();
		// remove the old control name from the internal list but keep the slot available
		removeControl(old_control_name, false);
		// add new control with the old slot
		addControl(new_control_name, new_control_name, slot);
		// grab the new values and make the selection border go to the right panel
		selectControl(new_control_name);
		// restore the old UI settings
		if (LLStringUtil::startsWith(old_parameters.label, "NewControl") || old_parameters.label == old_control_name) {
			// ViewerVR: .. unless we are "autonaming" and in that case adopt raw setting name (which user can still change)
			LL_WARNS() << "Using control_name as default label... mSelectedControl: " << mSelectedControl << " label:" << mControlsList[mSelectedControl].label << LL_ENDL;
		} else {
			mControlsList[mSelectedControl].label = old_parameters.label;
		}
		// find the control variable in global or per account settings
		LLControlVariable* var = gSavedSettings.getControl(mSelectedControl);
		if (!var)
		{
			var = gSavedPerAccountSettings.getControl(mSelectedControl);
		}

		if (var && hasControl(mSelectedControl))
		{
			// choose sane defaults for floating point controls, so the control value won't be destroyed
			// start with these
			F32 min_value = 0.0f;
			F32 max_value = 1.0f;
			F32 value = var->getValue().asReal();

			// if the value was negative and smaller than the current minimum
			if (value < 0.0f)
			{
				// make the minimum even smaller
				min_value = value * 2.0f;
			}
			// if the value is above zero, set max to double of the current value
			else if (value > 0.0f)
			{
				max_value = value * 2.0f;
			}

			// do a best guess on variable types and control widgets
			ControlType type;
			switch (var->type())
			{
				// Boolean gets the full set
				case TYPE_BOOLEAN:
				{
					// increment will be calculated below
					min_value = 0.0f;
					max_value = 1.0f;
					type = ControlTypeRadio;
					break;
				}
				// LLColor3/4 are just colors
				case TYPE_COL3:
				{
					type = ControlTypeColor3;
					break;
				}
				case TYPE_COL4:
				{
					type = ControlTypeColor4;
					break;
				}
				// U32 can never be negative
				case TYPE_U32:
				{
					min_value = 0.0f;
				}
				// Fallthrough, S32 and U32 are integer values
				case TYPE_S32:
				// Fallthrough, S32, U32 and F32 should use sliders
				case TYPE_F32:
				{
					type = ControlTypeSlider;
					break;
				}
				// Everything else gets a text widget for now
				default:
				{
					type=ControlTypeText;
				}
			}

			// choose a sane increment
			F32 increment = 0.1f;
			if (mControlsList[mSelectedControl].type == ControlTypeSlider)
			{
				// fine grained control for sliders
				increment = (max_value - min_value) / 100.0f;
			}
			else if (mControlsList[mSelectedControl].type == ControlTypeSpinner)
			{
				// not as fine grained for spinners
				increment = (max_value - min_value) / 20.0f;
			}

			// don't let values go too small
			if (increment < 0.1f)
			{
				increment = 0.1f;
			}

			// save calculated values to the edit widgets
			mControlsList[mSelectedControl].min_value = min_value;
			mControlsList[mSelectedControl].max_value = max_value;
			mControlsList[mSelectedControl].increment = increment;
			mControlsList[mSelectedControl].type = type; // old_parameters.type;
			mControlsList[mSelectedControl].widget->setValue(var->getValue());
		}
		// rebuild controls UI (probably not needed)
		// updateControls();
		// update our new control
		updateControl(mSelectedControl, mControlsList[mSelectedControl]);
	}
	// the control's setting variable is still the same, so just update the values
	else if (hasControl(mSelectedControl))
	{
		mControlsList[mSelectedControl].label = mControlLabelEdit->getValue().asString();
		mControlsList[mSelectedControl].type = (ControlType)mControlTypeCombo->getValue().asInteger();
		mControlsList[mSelectedControl].integer = mControlIntegerCheckbox->getValue().asBoolean();
		mControlsList[mSelectedControl].min_value = mControlMinSpinner->getValue().asReal();
		mControlsList[mSelectedControl].max_value = mControlMaxSpinner->getValue().asReal();
		mControlsList[mSelectedControl].increment = mControlIncrementSpinner->getValue().asReal();
		// and update the user interface
		updateControl(mSelectedControl, mControlsList[mSelectedControl]);
	}
	// select the control
	selectControl(mSelectedControl);
}

void FloaterVRPrefs::onAddNewClicked()
{
	// count a number to keep control names unique
	static S32 sCount = 0;
	std::string new_control_name = "NewControl" + llformat("%d", sCount);
	// add the new control to the internal list and user interface
	addControl(new_control_name, new_control_name);
	// put it at the bottom of the ordering stack
	mControlsOrder.push_back(new_control_name);
	sCount++;
	// select the newly created control
	selectControl(new_control_name);
}

void FloaterVRPrefs::onRemoveClicked(LLUICtrl* ctrl, void* userdata)
{
	// get the associated panel from the submitted userdata
	LLUICtrl* panel = (LLUICtrl*)userdata;
	// deselect the current entry
	selectControl("");
	// first remove the control from the ordering list
	mControlsOrder.remove(panel->getName());
	// then remove it from the internal list and from memory
	removeControl(panel->getName());
	// reinstate focus in case we lost it
	setFocus(TRUE);
}

void FloaterVRPrefs::onAlphaChanged(LLUICtrl* ctrl, void* userdata)
{
	// get the associated color swatch from the submitted userdata
	LLColorSwatchCtrl* color_swatch = (LLColorSwatchCtrl*)userdata;
	// get the current color
	LLColor4 color = color_swatch->get();
	// replace the alpha value of the color with the value in the alpha spinner
	color.setAlpha(ctrl->getValue().asReal());
	// save the color back into the color swatch
	color_swatch->getControlVariable()->setValue(color.getValue());
}

void FloaterVRPrefs::swapControls(const std::string& control1, const std::string& control2)
{
	// get the control entries of both controls
	ControlEntry temp_entry_1 = mControlsList[control1];
	ControlEntry temp_entry_2 = mControlsList[control2];

	// find the respective ordering slots
	LLView* temp_slot_1 = temp_entry_1.panel->getParent();
	LLView* temp_slot_2 = temp_entry_2.panel->getParent();

	// swap the controls around
	temp_slot_1->addChild(temp_entry_2.panel);
	temp_slot_2->addChild(temp_entry_1.panel);
}

void FloaterVRPrefs::onMoveUpClicked()
{
	// find the control in the ordering list
	std::list<std::string>::iterator it;
	for (it = mControlsOrder.begin(); it != mControlsOrder.end(); ++it)
	{
		if (*it == mSelectedControl)
		{
			// if it's already on top of the list, do nothing
			if (it == mControlsOrder.begin())
			{
				return;
			}

			// get the iterator of the previous item
			std::list<std::string>::iterator previous = it;
			--previous;

			// copy the previous item to the one we want to move
			*it = *previous;
			// copy the moving item to previous
			*previous = mSelectedControl;
			// update the user interface
			swapControls(mSelectedControl, *it);
			return;
		}
	}
	return;
}

void FloaterVRPrefs::onMoveDownClicked()
{
	// find the control in the ordering list
	std::list<std::string>::iterator it;
	for (it = mControlsOrder.begin(); it != mControlsOrder.end(); ++it)
	{
		if (*it == mSelectedControl)
		{
			// if it's already at the end of the list, do nothing
			if (*it == mControlsOrder.back())
			{
				return;
			}

			// get the iterator of the next item
			std::list<std::string>::iterator next = it;
			++next;

			// copy the next item to the one we want to move
			*it = *next;
			// copy the moving item to next
			*next = mSelectedControl;
			// update the user interface
			swapControls(mSelectedControl, *it);
			return;
		}
	}
	return;
}

void FloaterVRPrefs::onClose(bool app_quitting)
{

	// close edit mode and save settings
	gSavedSettings.setBOOL("VRPrefsEditMode", FALSE);
}
// </FS:Zi>

// <FS:CR> FIRE-9407 - Restore Quickprefs Defaults
void FloaterVRPrefs::callbackRestoreDefaults(const LLSD& notification, const LLSD& response)
{
	S32 option = LLNotificationsUtil::getSelectedOption(notification, response);
	if ( option == 0 ) // YES
	{
		selectControl("");
		BOOST_FOREACH(const std::string& control, mControlsOrder)
		{
			removeControl(control);
		}
		mControlsOrder.clear();
		std::string settings_file = LLAppViewer::instance()->getSettingsFilename("Default", "VRPreferences");
		LLFile::remove(gDirUtilp->getExpandedFilename(LL_PATH_USER_SETTINGS, settings_file));
		loadSavedSettingsFromFile(gDirUtilp->getExpandedFilename(LL_PATH_APP_SETTINGS, settings_file));
		gSavedSettings.setBOOL("VRPrefsEditMode", FALSE);
	}
	else
	{
		LL_INFOS() << "User cancelled the reset." << LL_ENDL;
	}
}

void FloaterVRPrefs::onClickRestoreDefaults()
{
	LLNotificationsUtil::add("ConfirmRestoreQuickPrefsDefaults", LLSD(), LLSD(), boost::bind(&FloaterVRPrefs::callbackRestoreDefaults, this, _1, _2));
}
// </FS:CR>

