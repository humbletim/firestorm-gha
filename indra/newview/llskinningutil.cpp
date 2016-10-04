/** 
* @file llskinningutil.cpp
* @brief  Functions for mesh object skinning
* @author vir@lindenlab.com
*
* $LicenseInfo:firstyear=2015&license=viewerlgpl$
* Second Life Viewer Source Code
* Copyright (C) 2015, Linden Research, Inc.
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

#include "llviewerprecompiledheaders.h"

#include "llskinningutil.h"
#include "llvoavatar.h"
#include "llviewercontrol.h"
#include "llmeshrepository.h"

bool LLSkinningUtil::sIncludeEnhancedSkeleton = true;

namespace {

//<FS:ND> Query by JointKey rather than just a string, the key can be a U32 index for faster lookup
//bool get_name_index( const std::string& name, std::vector<std::string>& names, U32& result )
bool get_name_index( const JointKey& name, std::vector<JointKey>& names, U32& result )
//</FS:ND>
{
	//<FS:ND> Query by JointKey rather than just a string, the key can be a U32 index for faster lookup
	// std::vector<std::string>::const_iterator find_it =
	std::vector<JointKey>::const_iterator find_it =
	// </FS:ND>
		std::find( names.begin(), names.end(), name );
    if (find_it != names.end())
    {
        result = find_it - names.begin();
        return true;
    }
    else
    {
        return false;
    }
}

// Find a name table index that is also a valid joint on the
// avatar. Order of preference is: requested name, mPelvis, first
// valid match in names table.
//<FS:ND> Query by JointKey rather than just a string, the key can be a U32 index for faster lookup
//U32 get_valid_joint_index( const std::string& name, LLVOAvatar *avatar, std::vector<std::string>& joint_names )
U32 get_valid_joint_index( const JointKey& name, LLVOAvatar *avatar, std::vector<JointKey>& joint_names )
//</FS:ND>
{
    U32 result;
    if (avatar->getJoint(name) && get_name_index(name,joint_names,result))
    {
        return result;
    }
//<FS:ND> Query by JointKey rather than just a string, the key can be a U32 index for faster lookup
//	if( get_name_index( "mPelvis", joint_names, result ) )
	if( get_name_index( JointKey::construct( "mPelvis" ), joint_names, result ) )
// </FS:ND>
	{
        return result;
    }
    for (U32 j=0; j<joint_names.size(); j++)
    {
        if (avatar->getJoint(joint_names[j]))
        {
            return j;
        }
    }
    // Shouldn't ever get here, because of the name cleanup pass in remapSkinInfoJoints()
    LL_ERRS() << "no valid joints in joint_names" << LL_ENDL;
    return 0;
}

// Which joint will stand in for this joint? 
//<FS:ND> Query by JointKey rather than just a string, the key can be a U32 index for faster lookup
//U32 get_proxy_joint_index( U32 joint_index, LLVOAvatar *avatar, std::vector<std::string>& joint_names )
U32 get_proxy_joint_index( U32 joint_index, LLVOAvatar *avatar, std::vector<JointKey>& joint_names )
//</FS:ND>
{
	bool include_enhanced = LLSkinningUtil::sIncludeEnhancedSkeleton;
    U32 j_proxy = get_valid_joint_index(joint_names[joint_index], avatar, joint_names);
    LLJoint *joint = avatar->getJoint(joint_names[j_proxy]);
    llassert(joint);
    // Find the first ancestor that's not flagged as extended, or the
    // last ancestor that's rigged in this mesh, whichever
    // comes first.
    while (1)
    {
        if (include_enhanced || 
            joint->getSupport()==LLJoint::SUPPORT_BASE)
            break;
        LLJoint *parent = joint->getParent();
        if (!parent)
            break;
		//<FS:ND> Query by JointKey rather than just a string, the key can be a U32 index for faster lookup
		// if( !get_name_index( parent->getName(), joint_names, j_proxy ) )
		if( !get_name_index( JointKey::construct( parent->getName() ), joint_names, j_proxy ) )
		// </FS:ND>
		{
            break;
        }
        joint = parent;
    }
    return j_proxy;
}

}

// static
void LLSkinningUtil::initClass()
{
    sIncludeEnhancedSkeleton = gSavedSettings.getBOOL("IncludeEnhancedSkeleton");
}

// static
U32 LLSkinningUtil::getMaxJointCount()
{
    U32 result = LL_MAX_JOINTS_PER_MESH_OBJECT;
    if (!sIncludeEnhancedSkeleton)
    {
        // Currently the remap logic does not guarantee joint count <= 52;
        // if one of the base ancestors is not rigged in a given mesh, an extended
		// joint can still be included.
        result = llmin(result,(U32)52);
    }
	return result;
}

// static
U32 LLSkinningUtil::getMeshJointCount(const LLMeshSkinInfo *skin)
{
	return llmin((U32)getMaxJointCount(), (U32)skin->mJointNames.size());
}

// static

// Destructively remap the joints in skin info based on what joints
// are known in the avatar, and which are currently supported.  This
// will also populate mJointRemap[] in the skin, which can be used to
// make the corresponding changes to the integer part of vertex
// weights.
//
// This will throw away joint info for any joints that are not known
// in the avatar, or not currently flagged to support based on the
// debug setting for IncludeEnhancedSkeleton.
//

// BENTO maybe this really only makes sense for new leaf joints? New spine
// joints may need different logic.

// static
void LLSkinningUtil::remapSkinInfoJoints(LLVOAvatar *avatar, LLMeshSkinInfo* skin)
{
	// skip if already done.
    if (!skin->mJointRemap.empty())
    {
        return; 
    }

    U32 max_joints = getMeshJointCount(skin);

    // Compute the remap
    for (U32 j = 0; j < skin->mJointNames.size(); ++j)
    {
        // Fix invalid names to "mPelvis". Currently meshes with
        // invalid names will be blocked on upload, so this is just
        // needed for handling of any legacy bad data.
        if (!avatar->getJoint(skin->mJointNames[j]))
        {
//<FS:ND> Query by JointKey rather than just a string, the key can be a U32 index for faster lookup
//			skin->mJointNames[ j ] = "mPelvis";
			skin->mJointNames[ j ] = JointKey::construct( "mPelvis" );
//</FS:ND>
		}
    }
    std::vector<U32> j_proxy(skin->mJointNames.size());
    for (U32 j = 0; j < skin->mJointNames.size(); ++j)
    {
        U32 j_rep = get_proxy_joint_index(j, avatar, skin->mJointNames);
        j_proxy[j] = j_rep;
    }
    S32 top = 0;
    std::vector<U32> j_remap(skin->mJointNames.size());
    // Fill in j_remap for all joints that will be kept.
    for (U32 j = 0; j < skin->mJointNames.size(); ++j)
    {
        if (j_proxy[j] == j)
        {
            // Joint will be included
            j_remap[j] = top;
            if (top < max_joints-1)
            {
                top++;
            }
        }
    }
    // Then use j_proxy to fill in j_remap for the joints that will be discarded
    for (U32 j = 0; j < skin->mJointNames.size(); ++j)
    {
        if (j_proxy[j] != j)
        {
            j_remap[j] = j_remap[j_proxy[j]];
        }
    }
    
    
    // Apply the remap to mJointNames, mInvBindMatrix, and mAlternateBindMatrix
    //<FS:ND> Query by JointKey rather than just a string, the key can be a U32 index for faster lookup
    // std::vector<std::string> new_joint_names;
    std::vector< JointKey > new_joint_names;
    // </FS:ND>
    std::vector<S32> new_joint_nums;
    std::vector<LLMatrix4> new_inv_bind_matrix;
    std::vector<LLMatrix4> new_alternate_bind_matrix;

    for (U32 j = 0; j < skin->mJointNames.size(); ++j)
    {
        if (j_proxy[j] == j && new_joint_names.size() < max_joints)
        {
            new_joint_names.push_back(skin->mJointNames[j]);
            new_joint_nums.push_back(-1);
            new_inv_bind_matrix.push_back(skin->mInvBindMatrix[j]);
            if (!skin->mAlternateBindMatrix.empty())
            {
                new_alternate_bind_matrix.push_back(skin->mAlternateBindMatrix[j]);
            }
        }
    }
    llassert(new_joint_names.size() <= max_joints);

    for (U32 j = 0; j < skin->mJointNames.size(); ++j)
    {
        if (skin->mJointNames[j] != new_joint_names[j_remap[j]])
        {
            LL_DEBUGS("Avatar") << "Starting joint[" << j << "] = " << skin->mJointNames[j] << " j_remap " << j_remap[j] << " ==> " << new_joint_names[j_remap[j]] << LL_ENDL;
        }
    }

    skin->mJointNames = new_joint_names;
    skin->mInvBindMatrix = new_inv_bind_matrix;
    skin->mAlternateBindMatrix = new_alternate_bind_matrix;
    skin->mJointRemap = j_remap;
}

// static
void LLSkinningUtil::initSkinningMatrixPalette(
    LLMatrix4* mat,
    S32 count, 
    const LLMeshSkinInfo* skin,
    LLVOAvatar *avatar)
{
    for (U32 j = 0; j < count; ++j)
    {
        LLJoint *joint = NULL;
        if (skin->mJointNums[j] == -1)
        {
            joint = avatar->getJoint(skin->mJointNames[j]);
            if (joint)
            {
                skin->mJointNums[j] = joint->getJointNum();
            }
        }
		else
		{
			joint = avatar->getJoint(skin->mJointNums[j]);
		}
        if (joint)
        {
#define MAT_USE_SSE
#ifdef MAT_USE_SSE
            LLMatrix4a bind, world, res;
            bind.loadu(skin->mInvBindMatrix[j]);
            world.loadu(joint->getWorldMatrix());
            matMul(bind,world,res);
            memcpy(mat[j].mMatrix,res.mMatrix,16*sizeof(float));
#else
            mat[j] = skin->mInvBindMatrix[j];
            mat[j] *= joint->getWorldMatrix();
#endif
        }
        else
        {
            mat[j] = skin->mInvBindMatrix[j];
            // This  shouldn't  happen   -  in  mesh  upload,  skinned
            // rendering  should  be disabled  unless  all joints  are
            // valid.  In other  cases of  skinned  rendering, invalid
            // joints should already have  been removed during remap.
            LL_WARNS_ONCE("Avatar") << "Rigged to invalid joint name " << skin->mJointNames[j] << LL_ENDL;
        }
    }
}

// Transform the weights based on the remap info stored in skin. Note
// that this is destructive and non-idempotent, so we need to keep
// track of whether we've done it already. If the desired remapping
// changes, the viewer must be restarted.
//
// static
void LLSkinningUtil::remapSkinWeights(LLVector4a* weights, U32 num_vertices, const LLMeshSkinInfo* skin)
{
	checkSkinWeights(weights, num_vertices, skin);
    llassert(skin->mJointRemap.size()>0); // Must call remapSkinInfoJoints() first, which this checks for.
    const U32* remap = &skin->mJointRemap[0];
    const S32 max_joints = skin->mJointRemap.size();
    for (U32 j=0; j<num_vertices; j++)
    {
        F32 *w = weights[j].getF32ptr();

        for (U32 k=0; k<4; ++k)
        {
            S32 i = llfloor(w[k]);
            F32 f = w[k]-i;
            i = llclamp(i,0,max_joints-1);
            w[k] = remap[i] + f;
        }
    }
	checkSkinWeights(weights, num_vertices, skin);
}

// static
void LLSkinningUtil::checkSkinWeights(LLVector4a* weights, U32 num_vertices, const LLMeshSkinInfo* skin)
{
#ifndef LL_RELEASE_FOR_DOWNLOAD
	const S32 max_joints = skin->mJointRemap.size();
    if (skin->mJointRemap.size()>0)
    {
        // Check the weights are consistent with the current remap.
        for (U32 j=0; j<num_vertices; j++)
        {
            F32 *w = weights[j].getF32ptr();
            
            F32 wsum = 0.0;
            for (U32 k=0; k<4; ++k)
            {
                S32 i = llfloor(w[k]);
                llassert(i>=0);
                llassert(i<max_joints);
                wsum += w[k]-i;
            }
            llassert(wsum > 0.0f);
        }
    }
#endif
}

// static
void LLSkinningUtil::getPerVertexSkinMatrix(
    F32* weights,
    LLMatrix4a* mat,
    bool handle_bad_scale,
    LLMatrix4a& final_mat,
    U32 max_joints)
{
    bool valid_weights = true;
    final_mat.clear();

    S32 idx[4];

    LLVector4 wght;

    F32 scale = 0.f;
    for (U32 k = 0; k < 4; k++)
    {
        F32 w = weights[k];

        // BENTO potential optimizations
        // - Do clamping in unpackVolumeFaces() (once instead of every time)
        // - int vs floor: if we know w is
        // >= 0.0, we can use int instead of floorf; the latter
        // allegedly has a lot of overhead due to ieeefp error
        // checking which we should not need.
        idx[k] = llclamp((S32) floorf(w), (S32)0, (S32)max_joints-1);

        wght[k] = w - floorf(w);
        scale += wght[k];
    }
    if (handle_bad_scale && scale <= 0.f)
    {
        wght = LLVector4(1.0f, 0.0f, 0.0f, 0.0f);
        valid_weights = false;
    }
    else
    {
        // This is enforced  in unpackVolumeFaces()
        llassert(scale>0.f);
        wght *= 1.f/scale;
    }

    for (U32 k = 0; k < 4; k++)
    {
        F32 w = wght[k];

        LLMatrix4a src;
        src.setMul(mat[idx[k]], w);

        final_mat.add(src);
    }
    // SL-366 - with weight validation/cleanup code, it should no longer be
    // possible to hit the bad scale case.
    llassert(valid_weights);
}

