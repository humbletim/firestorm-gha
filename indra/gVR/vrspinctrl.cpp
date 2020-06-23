/** 
 * @file vrspinctrl.cpp
 * @brief VRSpinCtrl base class (based on LLSpinCtrl)
 *
 * $LicenseInfo:firstyear=2001&license=viewerlgpl$
 * Second Life Viewer Source Code
 * Copyright (C) 2010, Linden Research, Inc.
 * Copyright (C) 2020, humbletim
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
 * $/LicenseInfo$
 */

#include "linden_common.h"
 
#include "vrspinctrl.h"

#include "llgl.h"
#include "llui.h"
#include "lluiconstants.h"

#include "llstring.h"
#include "llfontgl.h"
#include "lllineeditor.h"
#include "llbutton.h"
#include "lltextbox.h"
#include "llkeyboard.h"
#include "llmath.h"
#include "llcontrol.h"
#include "llfocusmgr.h"
#include "llresmgr.h"
#include "lluictrlfactory.h"

const U32 MAX_STRING_LENGTH = 255;

static LLDefaultChildRegistry::Register<VRSpinCtrl> r("vr_spinner");

namespace {
  bool poop = []{
  fprintf(stderr, "POOP vr_spinner!!!!! %d\n", 1);
  return true;
}();
}
VRSpinCtrl::Params::Params()
:	label_width("label_width"),
	decimal_digits("decimal_digits"),
	allow_text_entry("allow_text_entry", true),
	allow_digits_only("allow_digits_only", false),
	label_wrap("label_wrap", false),
	text_enabled_color("text_enabled_color"),
	text_disabled_color("text_disabled_color"),
	up_button("up_button"),
	down_button("down_button"),
	dynamic_button_height("dynamic_button_height", false) // <FS:Ansariel> Option to calculate dynamic button height
{}

VRSpinCtrl::VRSpinCtrl(const VRSpinCtrl::Params& p)
:	LLF32UICtrl(p),
	mLabelBox(NULL),
	mbHasBeenSet( FALSE ),
	mPrecision(p.decimal_digits),
	mTextEnabledColor(p.text_enabled_color()),
	mTextDisabledColor(p.text_disabled_color())
{
	static LLUICachedControl<S32> spinctrl_spacing ("$vrUISpinctrlSpacing", 0);
	static LLUICachedControl<S32> spinctrl_btn_width ("$vrUISpinctrlBtnWidth", 16);
	// <FS:Ansariel> Option to calculate dynamic button height
	//static LLUICachedControl<S32> spinctrl_btn_height ("UISpinctrlBtnHeight", 0);
	static LLUICachedControl<S32> spinctrl_btn_height_default ("$vrUISpinctrlBtnHeight", 16);
	S32 spinctrl_btn_height = p.dynamic_button_height ? getRect().getHeight() / 2 : spinctrl_btn_height_default();
	// </FS:Ansariel>
	S32 centered_top = getRect().getHeight();
	S32 centered_bottom = getRect().getHeight() - 2 * spinctrl_btn_height;
	S32 btn_left = 0;
	// reserve space for spinner
	S32 label_width = llclamp(p.label_width(), 0, llmax(0, getRect().getWidth() - 40));

	// Label
	if( !p.label().empty() )
	{
		LLRect label_rect( 0, centered_top, label_width, centered_bottom );
		LLTextBox::Params params;
		params.wrap(p.label_wrap);
		params.name("SpinCtrl Label");
		params.rect(label_rect);
		params.initial_value(p.label());
		if (p.font.isProvided())
		{
			params.font(p.font);
		}
		mLabelBox = LLUICtrlFactory::create<LLTextBox> (params);
		addChild(mLabelBox);

		btn_left += label_rect.mRight + spinctrl_spacing;
	}

	S32 btn_right = btn_left + spinctrl_btn_width;
	
	// Spin buttons
	LLButton::Params up_button_params(p.up_button);
	up_button_params.rect = LLRect(getRect().getWidth() - spinctrl_btn_width, getRect().getHeight(), getRect().getWidth(), getRect().getHeight() - spinctrl_btn_height);
	up_button_params.click_callback.function(boost::bind(&VRSpinCtrl::onUpBtn, this, _2));
	up_button_params.mouse_held_callback.function(boost::bind(&VRSpinCtrl::onUpBtn, this, _2));

	mUpBtn = LLUICtrlFactory::create<LLButton>(up_button_params);
	addChild(mUpBtn);

	LLButton::Params down_button_params(p.down_button);
	down_button_params.rect = LLRect(getRect().getWidth() - spinctrl_btn_width, getRect().getHeight() - spinctrl_btn_height, getRect().getWidth(), getRect().getHeight() - 2 * spinctrl_btn_height);
	down_button_params.click_callback.function(boost::bind(&VRSpinCtrl::onDownBtn, this, _2));
	down_button_params.mouse_held_callback.function(boost::bind(&VRSpinCtrl::onDownBtn, this, _2));
	mDownBtn = LLUICtrlFactory::create<LLButton>(down_button_params);
	addChild(mDownBtn);

	LLRect editor_rect( btn_left, centered_top, getRect().getWidth() - spinctrl_btn_width - btn_left, centered_bottom );
	LLLineEditor::Params params;
	params.name("SpinCtrl Editor");
	params.rect(editor_rect);
	if (p.font.isProvided())
	{
		params.font(p.font);
	}
	params.max_length.bytes(MAX_STRING_LENGTH);
	params.commit_callback.function((boost::bind(&VRSpinCtrl::onEditorCommit, this, _2)));
	
	//*NOTE: allow entering of any chars for LLCalc, proper input will be evaluated on commit
	
	params.follows.flags(FOLLOWS_LEFT | FOLLOWS_BOTTOM);
	mEditor = LLUICtrlFactory::create<LLLineEditor> (params);
	mEditor->setFocusReceivedCallback( boost::bind(&VRSpinCtrl::onEditorGainFocus, _1, this ));
	mEditor->setFocusLostCallback( boost::bind(&VRSpinCtrl::onEditorLostFocus, _1, this ));
	if (p.allow_digits_only)
	{
		mEditor->setPrevalidateInput(LLTextValidate::validateNonNegativeS32NoSpace);
	}
	//RN: this seems to be a BAD IDEA, as it makes the editor behavior different when it has focus
	// than when it doesn't.  Instead, if you always have to double click to select all the text, 
	// it's easier to understand
	//mEditor->setSelectAllonFocusReceived(TRUE);
	mEditor->setSelectAllonCommit(FALSE);
	addChild(mEditor);

	updateEditor();
	setUseBoundingRect( TRUE );
}

namespace {
F32 clamp_precision(F32 value, S32 decimal_precision)
{
	// pow() isn't perfect
	
	F64 clamped_value = value;
	for (S32 i = 0; i < decimal_precision; i++)
		clamped_value *= 10.0;

	clamped_value = ll_round(clamped_value);

	for (S32 i = 0; i < decimal_precision; i++)
		clamped_value /= 10.0;
	
	return (F32)clamped_value;
}
}

void VRSpinCtrl::onUpBtn( const LLSD& data )
{
	if( getEnabled() )
	{
		std::string text = mEditor->getText();
		if( LLLineEditor::postvalidateFloat( text ) )
		{
			
			LLLocale locale(LLLocale::USER_LOCALE);
			F32 cur_val = (F32) atof(text.c_str());
		
			// use getValue()/setValue() to force reload from/to control
			// <FS:KC> alt/ctrl/shift keys modify increment
			//F32 val = cur_val + mIncrement;
			F32 inc = mIncrement;
			if (gKeyboard->getKeyDown(KEY_ALT))
			{
				inc *= 10.f;
			}
			else if (gKeyboard->getKeyDown(KEY_CONTROL))
			{
				inc *= 0.1f;
			}
			else if (gKeyboard->getKeyDown(KEY_SHIFT))
			{
				inc *= 0.01f;
			}
			F32 val = cur_val + inc;
			// </FS:KC>
			val = clamp_precision(val, mPrecision);
			val = llmin( val, mMaxValue );
			if (val < mMinValue) val = mMinValue;
			if (val > mMaxValue) val = mMaxValue;
		
			F32 saved_val = (F32)getValue().asReal();
			setValue(val);
			if( mValidateSignal && !(*mValidateSignal)( this, val ) )
			{
				setValue( saved_val );
				reportInvalidData();
				updateEditor();
				return;
			}

		updateEditor();
		onCommit();
		}
	}
}

void VRSpinCtrl::onDownBtn( const LLSD& data )
{
	if( getEnabled() )
	{
		std::string text = mEditor->getText();
		if( LLLineEditor::postvalidateFloat( text ) )
		{

			LLLocale locale(LLLocale::USER_LOCALE);
			F32 cur_val = (F32) atof(text.c_str());
		
			// <FS:KC> alt/ctrl/shift keys modify increment
			//F32 val = cur_val - mIncrement;
			F32 inc = mIncrement;
			if (gKeyboard->getKeyDown(KEY_ALT))
			{
				inc *= 10.f;
			}
			else if (gKeyboard->getKeyDown(KEY_CONTROL))
			{
				inc *= 0.1f;
			}
			else if (gKeyboard->getKeyDown(KEY_SHIFT))
			{
				inc *= 0.01f;
			}
			F32 val = cur_val - inc;
			// </FS:KC>
			val = clamp_precision(val, mPrecision);
			val = llmax( val, mMinValue );

			if (val < mMinValue) val = mMinValue;
			if (val > mMaxValue) val = mMaxValue;
			
			F32 saved_val = (F32)getValue().asReal();
			setValue(val);
			if( mValidateSignal && !(*mValidateSignal)( this, val ) )
			{
				setValue( saved_val );
				reportInvalidData();
				updateEditor();
				return;
			}
		
			updateEditor();
			onCommit();
		}
	}
}

// static
void VRSpinCtrl::onEditorGainFocus( LLFocusableElement* caller, void *userdata )
{
	VRSpinCtrl* self = (VRSpinCtrl*) userdata;
	llassert( caller == self->mEditor );

	self->onFocusReceived();
}

// static
void VRSpinCtrl::onEditorLostFocus( LLFocusableElement* caller, void *userdata )
{
	VRSpinCtrl* self = (VRSpinCtrl*) userdata;
	llassert( caller == self->mEditor );

	self->onFocusLost();

	std::string text = self->mEditor->getText();

	LLLocale locale(LLLocale::USER_LOCALE);
	F32 val = (F32)atof(text.c_str());

	F32 saved_val = self->getValueF32();
	if (saved_val != val && !self->mEditor->isDirty())
	{
		// Editor was focused when value update arrived, string
		// in editor is different from one in spin control.
		// Since editor is not dirty, it won't commit, so either
		// attempt to commit value from editor or revert to a more
		// recent value from spin control
		self->updateEditor();
	}
}

void VRSpinCtrl::setValue(const LLSD& value )
{
	F32 v = (F32)value.asReal();
	if (getValueF32() != v || !mbHasBeenSet)
	{
		mbHasBeenSet = TRUE;
        LLF32UICtrl::setValue(value);
		
		if (!mEditor->hasFocus())
		{
			updateEditor();
		}
	}
}

//no matter if Editor has the focus, update the value
void VRSpinCtrl::forceSetValue(const LLSD& value )
{
	F32 v = (F32)value.asReal();
	if (getValueF32() != v || !mbHasBeenSet)
	{
		mbHasBeenSet = TRUE;
        LLF32UICtrl::setValue(value);
		
		updateEditor();
		mEditor->resetScrollPosition();
	}
}

void VRSpinCtrl::clear()
{
	setValue(mMinValue);
	mEditor->clear();
	mbHasBeenSet = FALSE;
}

void VRSpinCtrl::updateLabelColor()
{
	if( mLabelBox )
	{
		mLabelBox->setColor( getEnabled() ? mTextEnabledColor.get() : mTextDisabledColor.get() );
	}
}

void VRSpinCtrl::updateEditor()
{
	LLLocale locale(LLLocale::USER_LOCALE);

	// Don't display very small negative valu	es as -0.000
	F32 displayed_value = clamp_precision((F32)getValue().asReal(), mPrecision);

//	if( S32( displayed_value * pow( 10, mPrecision ) ) == 0 )
//	{
//		displayed_value = 0.f;
//	}

	std::string format = llformat("%%.%df", mPrecision);
	std::string text = llformat(format.c_str(), displayed_value);
	mEditor->setText( text );
}

void VRSpinCtrl::onEditorCommit( const LLSD& data )
{
	BOOL success = FALSE;
	
	if( mEditor->evaluateFloat() )
	{
		std::string text = mEditor->getText();

		LLLocale locale(LLLocale::USER_LOCALE);
		F32 val = (F32) atof(text.c_str());

		if (val < mMinValue) val = mMinValue;
		if (val > mMaxValue) val = mMaxValue;

		F32 saved_val = getValueF32();
		setValue(val);
		if( !mValidateSignal || (*mValidateSignal)( this, val ) )
		{
			success = TRUE;
			onCommit();
		}
		else
		{
			setValue(saved_val);
		}
	}
	updateEditor();

	if( success )
	{
		// We commited and clamped value
		// try to display as much as possible
		mEditor->resetScrollPosition();
	}
	else
	{
		reportInvalidData();		
	}
}


void VRSpinCtrl::forceEditorCommit()
{
	onEditorCommit( LLSD() );
}


void VRSpinCtrl::setFocus(BOOL b)
{
	LLUICtrl::setFocus( b );
	mEditor->setFocus( b );
}

void VRSpinCtrl::setEnabled(BOOL b)
{
	LLView::setEnabled( b );
	mEditor->setEnabled( b );
	updateLabelColor();
}


void VRSpinCtrl::setTentative(BOOL b)
{
	mEditor->setTentative(b);
	LLUICtrl::setTentative(b);
}


BOOL VRSpinCtrl::isMouseHeldDown() const
{
	return 
		mDownBtn->hasMouseCapture()
		|| mUpBtn->hasMouseCapture();
}

void VRSpinCtrl::onCommit()
{
	setTentative(FALSE);
	setControlValue(getValueF32());
	LLF32UICtrl::onCommit();
}


void VRSpinCtrl::setPrecision(S32 precision)
{
	if (precision < 0 || precision > 10)
	{
		LL_ERRS() << "VRSpinCtrl::setPrecision - precision out of range" << LL_ENDL;
		return;
	}

	mPrecision = precision;
	updateEditor();
}

void VRSpinCtrl::setLabel(const LLStringExplicit& label)
{
	if (mLabelBox)
	{
		mLabelBox->setText(label);
	}
	else
	{
		LL_WARNS() << "Attempting to set label on VRSpinCtrl constructed without one " << getName() << LL_ENDL;
	}
	updateLabelColor();
}

// <FS:Ansariel> Allow setting an argument on the label
BOOL VRSpinCtrl::setLabelArg(const std::string& key, const LLStringExplicit& text)
{
	if (mLabelBox)
	{
		mLabelBox->setTextArg(key, text);
	}
	else
	{
		LL_WARNS() << "Attempting to set label argument on VRSpinCtrl constructed without one " << getName() << LL_ENDL;
	}
	updateLabelColor();

	return TRUE;
}
// </FS:Ansariel> Allow setting an argument on the label

void VRSpinCtrl::setAllowEdit(BOOL allow_edit)
{
	mEditor->setEnabled(allow_edit);
	mAllowEdit = allow_edit;
}

void VRSpinCtrl::onTabInto()
{
	mEditor->onTabInto(); 
}


void VRSpinCtrl::reportInvalidData()
{
	make_ui_sound("UISndBadKeystroke");
}

BOOL VRSpinCtrl::handleScrollWheel(S32 x, S32 y, S32 clicks)
{
	if( clicks > 0 )
	{
		while( clicks-- )
		{
			onDownBtn(getValue());
		}
	}
	else
	while( clicks++ )
	{
		onUpBtn(getValue());
	}

	return TRUE;
}

BOOL VRSpinCtrl::handleKeyHere(KEY key, MASK mask)
{
	if (mEditor->hasFocus())
	{
		if(key == KEY_ESCAPE)
		{
			// text editors don't support revert normally (due to user confusion)
			// but not allowing revert on a spinner seems dangerous
			updateEditor();
			mEditor->resetScrollPosition();
			mEditor->setFocus(FALSE);
			return TRUE;
		}
		if(key == KEY_UP)
		{
			onUpBtn(getValue());
			return TRUE;
		}
		if(key == KEY_DOWN)
		{
			onDownBtn(getValue());
			return TRUE;
		}
	}
	return FALSE;
}

