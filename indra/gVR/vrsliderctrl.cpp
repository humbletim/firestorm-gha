/** 
 * @file VRSliderCtrl.cpp
 * @brief VRSliderCtrl base class (based on LLSliderCtrl)
 *
 * $LicenseInfo:firstyear=2002&license=viewerlgpl$
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

#include "vrsliderctrl.h"

#include "llmath.h"
#include "llfontgl.h"
#include "llgl.h"
#include "llkeyboard.h"
#include "lllineeditor.h"
#include "llstring.h"
#include "lltextbox.h"
#include "llui.h"
#include "lluiconstants.h"
#include "llcontrol.h"
#include "llfocusmgr.h"
#include "llresmgr.h"
#include "lluictrlfactory.h"

static LLDefaultChildRegistry::Register<VRSliderCtrl> r("vr_slider");
static LLDefaultChildRegistry::Register<VRSlider> r2("vr_slider_bar");

BOOL VRSlider::handleMouseDown(S32 x, S32 y, MASK mask) {
  down = { x, y };
  return LLSlider::handleMouseDown(x, y, mask);
}

BOOL VRSlider::handleHover(S32 x, S32 y, MASK mask) {
  hover = mHorizontal && hasMouseCapture() ? 
    xy{ down.x + (S32)(mScaleValue * (F32)(x - down.x)), y } :
    xy{ x, y };
  return LLSlider::handleHover(hover.x, hover.y, mask);
}

// faking a mouse up using VR controllers often has jitter; simulate up position using last hover for consistency
BOOL VRSlider::handleMouseUp(S32 x, S32 y, MASK mask) {
  xy up = mHorizontal && hasMouseCapture() ? xy{ x, y } : hover;
  return LLSlider::handleMouseUp(up.x, up.y, mask);
}

VRSliderCtrl::VRSliderCtrl(const VRSliderCtrl::Params& p)
:	LLF32UICtrl(p),
	mLabelBox( NULL ),
	mEditor( NULL ),
	mTextBox( NULL ),
	mFont(p.font),
	mShowText(p.show_text),
	mCanEditText(p.can_edit_text),
	mPrecision(p.decimal_digits),
	mTextEnabledColor(p.text_color()),
	mTextDisabledColor(p.text_disabled_color()),
	mLabelWidth(p.label_width),
	mEditorCommitSignal(NULL)
{
	S32 top = getRect().getHeight();
	S32 bottom = 0;
	S32 left = 0;

	S32 label_width = p.label_width;
	S32 text_width = p.text_width;

	// Label
	if( !p.label().empty() )
	{
		if (!p.label_width.isProvided())
		{
			label_width = p.font()->getWidth(p.label);
		}
		LLRect label_rect( left, top, label_width, bottom );
		LLTextBox::Params params(p.slider_label);
		if (!params.rect.isProvided())
		{
			params.rect = label_rect;
		}
		if (!params.font.isProvided())
		{
			params.font = p.font;
		}
		params.initial_value(p.label());
		mLabelBox = LLUICtrlFactory::create<LLTextBox> (params);
		addChild(mLabelBox);
		mLabelFont = params.font();
	}

	if (p.show_text && !p.text_width.isProvided())
	{
		// calculate the size of the text box (log max_value is number of digits - 1 so plus 1)
		if ( p.max_value )
			text_width = p.font()->getWidth(std::string("0")) * ( static_cast < S32 > ( log10  ( p.max_value ) ) + p.decimal_digits + 1 );

		if ( p.increment < 1.0f )
			text_width += p.font()->getWidth(std::string("."));	// (mostly) take account of decimal point in value

		if ( p.min_value < 0.0f || p.max_value < 0.0f )
			text_width += p.font()->getWidth(std::string("-"));	// (mostly) take account of minus sign 

		// padding to make things look nicer
		text_width += 8;
	}


	S32 text_left = getRect().getWidth() - text_width;
	static LLUICachedControl<S32> sliderctrl_spacing ("UISliderctrlSpacing", 0);

	S32 slider_right = getRect().getWidth();
	if( p.show_text )
	{
		slider_right = text_left - sliderctrl_spacing;
	}

	S32 slider_left = label_width ? label_width + sliderctrl_spacing : 0;
	VRSlider::Params slider_p(p.slider_bar);
  slider_p.scale_value = 0.1f;
	slider_p.name("vr_slider_bar");
	if (!slider_p.rect.isProvided())
	{
		slider_p.rect = LLRect(slider_left,top,slider_right,bottom);
	}
	if (!slider_p.initial_value.isProvided())
	{
		slider_p.initial_value = p.initial_value().asReal();
	}
	if (!slider_p.min_value.isProvided())
	{
		slider_p.min_value = p.min_value;
	}
	if (!slider_p.max_value.isProvided())
	{
		slider_p.max_value = p.max_value;
	}
	if (!slider_p.increment.isProvided())
	{
		slider_p.increment = p.increment;
	}
	if (!slider_p.orientation.isProvided())
	{
		slider_p.orientation = p.orientation;
	}
	
	slider_p.commit_callback.function = &VRSliderCtrl::onSliderCommit;
	slider_p.control_name = p.control_name;
	slider_p.mouse_down_callback( p.mouse_down_callback );
	slider_p.mouse_up_callback( p.mouse_up_callback );
	mSlider = LLUICtrlFactory::create<VRSlider> (slider_p);

	addChild( mSlider );
	
	if( p.show_text() )
	{
		LLRect text_rect( text_left, top, getRect().getWidth(), bottom );
		if( p.can_edit_text() )
		{
			LLLineEditor::Params line_p(p.value_editor);
			if (!line_p.rect.isProvided())
			{
				line_p.rect = text_rect;
			}
			if (!line_p.font.isProvided())
			{
				line_p.font = p.font;
			}
			
			line_p.commit_callback.function(&VRSliderCtrl::onEditorCommit);
			line_p.prevalidate_callback(&LLTextValidate::validateFloat);
			mEditor = LLUICtrlFactory::create<LLLineEditor>(line_p);

			mEditor->setFocusReceivedCallback( boost::bind(&VRSliderCtrl::onEditorGainFocus, _1, this ));
			// don't do this, as selecting the entire text is single clicking in some cases
			// and double clicking in others
			//mEditor->setSelectAllonFocusReceived(TRUE);
			addChild(mEditor);
		}
		else
		{
			LLTextBox::Params text_p(p.value_text);
			if (!text_p.rect.isProvided())
			{
				text_p.rect = text_rect;
			}
			if (!text_p.font.isProvided())
			{
				text_p.font = p.font;
			}
			mTextBox = LLUICtrlFactory::create<LLTextBox>(text_p);
			addChild(mTextBox);
		}
	}

	updateText();
}

VRSliderCtrl::~VRSliderCtrl()
{
	delete mEditorCommitSignal;
}

// static
void VRSliderCtrl::onEditorGainFocus( LLFocusableElement* caller, void *userdata )
{
	VRSliderCtrl* self = (VRSliderCtrl*) userdata;
	llassert( caller == self->mEditor );

	self->onFocusReceived();
}


void VRSliderCtrl::setValue(F32 v, BOOL from_event)
{
	mSlider->setValue( v, from_event );
	mValue = mSlider->getValueF32();
	updateText();
}

BOOL VRSliderCtrl::setLabelArg( const std::string& key, const LLStringExplicit& text )
{
	BOOL res = FALSE;
	if (mLabelBox)
	{
		res = mLabelBox->setTextArg(key, text);
		if (res && mLabelFont && mLabelWidth == 0)
		{
			S32 label_width = mLabelFont->getWidth(mLabelBox->getText());
			LLRect rect = mLabelBox->getRect();
			S32 prev_right = rect.mRight;
			rect.mRight = rect.mLeft + label_width;
			mLabelBox->setRect(rect);
				
			S32 delta = rect.mRight - prev_right;
			rect = mSlider->getRect();
			S32 left = rect.mLeft + delta;
			static LLUICachedControl<S32> sliderctrl_spacing ("UISliderctrlSpacing", 0);
			left = llclamp(left, 0, rect.mRight - sliderctrl_spacing);
			rect.mLeft = left;
			mSlider->setRect(rect);
		}
	}
	return res;
}

void VRSliderCtrl::clear()
{
	setValue(0.0f);
	if( mEditor )
	{
		mEditor->setText( LLStringUtil::null );
	}
	if( mTextBox )
	{
		mTextBox->setText( LLStringUtil::null );
	}

}

void VRSliderCtrl::updateText()
{
	if( mEditor || mTextBox )
	{
		LLLocale locale(LLLocale::USER_LOCALE);

		// Don't display very small negative values as -0.000
		F32 displayed_value = (F32)(floor(getValueF32() * pow(10.0, (F64)mPrecision) + 0.5) / pow(10.0, (F64)mPrecision));

		std::string format = llformat("%%.%df", mPrecision);
		std::string text = llformat(format.c_str(), displayed_value);
		if( mEditor )
		{
			// Setting editor text here to "" before using actual text is here because if text which
			// is set is the same as the one which is actually typed into lineeditor, LLLineEditor::setText()
			// will exit at it's beginning, so text for revert on escape won't be saved. (EXT-8536)
			mEditor->setText( LLStringUtil::null );
			mEditor->setText( text );
		}
		else
		{
			mTextBox->setText( text );
		}
	}
}

// static
void VRSliderCtrl::onEditorCommit( LLUICtrl* ctrl, const LLSD& userdata )
{
	VRSliderCtrl* self = dynamic_cast<VRSliderCtrl*>(ctrl->getParent());
	if (!self)
		return;

	BOOL success = FALSE;
	F32 val = self->mValue;
	F32 saved_val = self->mValue;

	std::string text = self->mEditor->getText();
	if( LLLineEditor::postvalidateFloat( text ) )
	{
		LLLocale locale(LLLocale::USER_LOCALE);
		val = (F32) atof( text.c_str() );
		if( self->mSlider->getMinValue() <= val && val <= self->mSlider->getMaxValue() )
		{
			self->setValue( val );  // set the value temporarily so that the callback can retrieve it.
			if( !self->mValidateSignal || (*(self->mValidateSignal))( self, val ) )
			{
				success = TRUE;
			}
		}
	}

	if( success )
	{
		self->onCommit();
		if (self->mEditorCommitSignal)
			(*(self->mEditorCommitSignal))(self, self->getValueF32());
	}
	else
	{
		if( self->getValueF32() != saved_val )
		{
			self->setValue( saved_val );
		}
		self->reportInvalidData();		
	}
	self->updateText();
}

// static
void VRSliderCtrl::onSliderCommit( LLUICtrl* ctrl, const LLSD& userdata )
{
	VRSliderCtrl* self = dynamic_cast<VRSliderCtrl*>(ctrl->getParent());
	if (!self)
		return;

	BOOL success = FALSE;
	F32 saved_val = self->mValue;
	F32 new_val = self->mSlider->getValueF32();

	self->mValue = new_val;  // set the value temporarily so that the callback can retrieve it.
	if( !self->mValidateSignal || (*(self->mValidateSignal))( self, new_val ) )
	{
		success = TRUE;
	}

	if( success )
	{
		self->onCommit();
	}
	else
	{
		if( self->mValue != saved_val )
		{
			self->setValue( saved_val );
		}
		self->reportInvalidData();		
	}
	self->updateText();
}

void VRSliderCtrl::setEnabled(BOOL b)
{
	LLView::setEnabled( b );

	if( mLabelBox )
	{
		mLabelBox->setColor( b ? mTextEnabledColor.get() : mTextDisabledColor.get() );
	}

	mSlider->setEnabled( b );

	if( mEditor )
	{
		mEditor->setEnabled( b );
	}

	if( mTextBox )
	{
		mTextBox->setColor( b ? mTextEnabledColor.get() : mTextDisabledColor.get() );
	}
}


void VRSliderCtrl::setTentative(BOOL b)
{
	if( mEditor )
	{
		mEditor->setTentative(b);
	}
	LLF32UICtrl::setTentative(b);
}


void VRSliderCtrl::onCommit()
{
	setTentative(FALSE);

	if( mEditor )
	{
		mEditor->setTentative(FALSE);
	}
	
	setControlValue(getValueF32());
	LLF32UICtrl::onCommit();
}


void VRSliderCtrl::setPrecision(S32 precision)
{
	if (precision < 0 || precision > 10)
	{
		LL_ERRS() << "VRSliderCtrl::setPrecision - precision out of range" << LL_ENDL;
		return;
	}

	mPrecision = precision;
	updateText();
}

boost::signals2::connection VRSliderCtrl::setSliderMouseDownCallback( const commit_signal_t::slot_type& cb )
{
	return mSlider->setMouseDownCallback( cb );
}

boost::signals2::connection VRSliderCtrl::setSliderMouseUpCallback( const commit_signal_t::slot_type& cb )
{
	return mSlider->setMouseUpCallback( cb );
}

boost::signals2::connection VRSliderCtrl::setSliderEditorCommitCallback( const commit_signal_t::slot_type& cb )   
{ 
	if (!mEditorCommitSignal) mEditorCommitSignal = new commit_signal_t();
	return mEditorCommitSignal->connect(cb); 
}
void VRSliderCtrl::onTabInto()
{
	if( mEditor )
	{
		mEditor->onTabInto(); 
	}
}

void VRSliderCtrl::reportInvalidData()
{
	make_ui_sound("UISndBadKeystroke");
}

