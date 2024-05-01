// potential workaround for hop://grid:port/Partial/x/y/z resolution
// 2024.04.30 humbletim

// notes:
// - just to make things more complicated... a special "="+region_name
//   - triggers the below helper code path
//   - the "=" is internal to the app; NOT sent with the region query
//   - MapNameRequest's are also sent flagless (0x0000, not using LAYER_FLAG)
//     - this is to avoid triggering OpenSim code paths that modify results
//       and make it impossible to discern Partial vs. Exact matching
// - gently wired into:
//   - llnavigationbar.cpp
//   - llurldispatcher.cpp
//   - llworldmapmessage.cpp

#include <string>
#include <regex>

#include "llcommon.h"
#include "llsingleton.h"
#include "llworldmapmessage.h"
#include "message.h"
#include "llworldmap.h" // grid_to_region_handle
#include "llagent.h"

namespace {
	// decipher various hop Region Name encodings
	inline std::string extract_region(std::string const& s) {
		static auto const& patterns = {
			std::regex{ R"(/ ([^/:=]+)$)" }, // TODO: figure out where the spec lives for hop "slash space" encoding...
			std::regex{ R"(([^/:=]+)$)" },   // TODO: figure out where the spec lives for hop "grid:port:region" encoding...
		};
		std::smatch match_results;
		for (auto const& pattern : patterns) {
			if (std::regex_search(s, match_results, pattern)) {
				return match_results[1].str();
			}
		}
		return s;
	} 
	// int main() {
	// 	for (const auto& s : {
	// 		"http://hg.osgrid.org:80/ Vue North",
	// 		"hop://hg.osgrid.org:80/ Vue North",
	// 		"hg.osgrid.org:80/ Vue North",
	// 		"hg.osgrid.org:80:Vue North",
	// 		"hg.osgrid.org:80/Vue North",
	// 	}) fprintf(stderr, "'%s' = '%s'\n", s, extract_region(s).c_str());fflush(stderr);
	// 	return 0;
	// }

	// helper to encapsulate Region Map Block responses
	struct _MapBlock {
		S32 block{};
		U16 x_regions{}, y_regions{}, x_size{ REGION_WIDTH_UNITS }, y_size{ REGION_WIDTH_UNITS };
		std::string name{};
		U8 accesscode{};
		U32 region_flags{};
		LLUUID image_id{};

		inline U32 x_world() const { return (U32)(x_regions) * REGION_WIDTH_UNITS; }
		inline U32 y_world() const { return (U32)(y_regions) * REGION_WIDTH_UNITS; }
		inline U64 region_handle() const { return grid_to_region_handle(x_regions, y_regions); }

		_MapBlock(LLMessageSystem* msg, S32 block) : block(block) {
			// FIXME: this duplicates LLWorldMapMessage::sendNamedRegionRequest...
			msg->getU16Fast(_PREHASH_Data, _PREHASH_X, x_regions, block);
			msg->getU16Fast(_PREHASH_Data, _PREHASH_Y, y_regions, block);
			msg->getStringFast(_PREHASH_Data, _PREHASH_Name, name, block);
			msg->getU8Fast(_PREHASH_Data, _PREHASH_Access, accesscode, block);
			msg->getU32Fast(_PREHASH_Data, _PREHASH_RegionFlags, region_flags, block);
	//		msg->getU8Fast(_PREHASH_Data, _PREHASH_WaterHeight, water_height, block);
	//		msg->getU8Fast(_PREHASH_Data, _PREHASH_Agents, agents, block);
			msg->getUUIDFast(_PREHASH_Data, _PREHASH_MapImageID, image_id, block);
	// <FS:CR> Aurora Sim
			if(msg->getNumberOfBlocksFast(_PREHASH_Size) > 0) {
				msg->getU16Fast(_PREHASH_Size, _PREHASH_SizeX, x_size, block);
				msg->getU16Fast(_PREHASH_Size, _PREHASH_SizeY, y_size, block);
			}
			if(x_size == 0 || (x_size % 16) != 0|| (y_size % 16) != 0) {
				x_size = 256;
				y_size = 256;
			}
	// </FS:CR> Aurora Sim
		}
	};

	// FIXME: capture references to LLWorldMapMessage name search privates
	// (for now this strategy avoids having to change core header files...)
	#define _RegionNameQuery_from(self) { \
		self->mSLURLRegionName, \
		self->mSLURLRegionHandle, \
		self->mSLURL, \
		self->mSLURLCallback, \
		self->mSLURLTeleport \
	}
	struct _RegionNameQuery {
		// NOTE: these members are all *references*
		std::string& mSLURLRegionName;
		U64& mSLURLRegionHandle;
		std::string& mSLURL; 
		LLWorldMapMessage::url_callback_t& mSLURLCallback;
		bool& mSLURLTeleport;
		
		inline bool matches(_MapBlock const& _block) {
			std::string search_name = extract_region(mSLURLRegionName);
			std::string block_name = extract_region(_block.name);
			bool equals = !search_name.empty() && LLStringUtil::compareInsensitive(search_name, block_name) == 0;
			if (!search_name.empty()) fprintf(stderr, "[xxHTxx] _RegionNameQuery.matches(%s, %s) == %d\n", search_name.c_str(), block_name.c_str(), equals);fflush(stderr);
			return equals;
		}

		inline bool resolve(_MapBlock const& _block) {
			auto callback = mSLURLCallback;
			auto region_name = mSLURLRegionName;
			auto handle = mSLURLRegionHandle;
			auto slurl = mSLURL;
			auto teleport = mSLURLTeleport;
			{
				mSLURLCallback = NULL;
				mSLURLRegionName.clear();
				mSLURLRegionHandle = 0;
				mSLURL.clear();
				mSLURLTeleport = false;
			}
			if (callback) {
				fprintf(stderr, "[xxHTxx] [handle=%llu] _RegionNameQuery.callback(%llu, %s, %s, %d)\n", 
					handle, _block.region_handle(), slurl.c_str(), _block.image_id.asString().c_str(), teleport);fflush(stderr);
				callback(_block.region_handle(), slurl, _block.image_id, teleport);
				return true;
			}
			return false;
		}
	}; // _RegionNameQuery

// see also: LLWorldMapMessage::processMapBlockReply
bool LLWorldMapMessage_processExactNamedRegionResponse(_RegionNameQuery&& query, LLMessageSystem* msg, U32 agent_flags) {
	// NOTE: we assume only agent_flags have been read from msg so far
	S32 num_blocks = msg->getNumberOfBlocksFast(_PREHASH_Data);
	fprintf(stderr, "[xxHTxx] LLWorldMapMessage_processExactNamedRegionResponse "
		"agent_flags=%04x query.name=%s query.handle=%llu query.callback=%s query.slurl=%s query.teleport=%s\n",
		agent_flags, query.mSLURLRegionName.c_str(), query.mSLURLRegionHandle, query.mSLURLCallback ? "(function)" : "(nil)", query.mSLURL.c_str(), query.mSLURLTeleport  ? "true" : "false"
	);fflush(stderr);
	bool resolved = false;
	for (S32 block=0; block < num_blocks; block++) {
		_MapBlock _block{msg, block};
		fprintf(stderr, "[xxHTxx]  [%02d] LLWorldMapMessage_processExactNamedRegionResponse block.handle=%llu block.name=%s\n", block, _block.region_handle(), _block.name.c_str());fflush(stderr);
		if (query.matches(_block)) resolved = query.resolve(_block) || resolved;
	}
	return resolved;
}

// see also: LLWorldMapMessage::sendNamedRegionRequest
void _LLWorldMapMessage_sendExactNamedRegionRequest(_RegionNameQuery&& query) {
		auto region_name = query.mSLURLRegionName;
		query.mSLURLRegionHandle = -1;

		fprintf(stderr, "[xxHTxx] sendExactNamedRegionRequest raw.region_name='%s' query.name='%s'\n", region_name.c_str(), region_name.substr(1).c_str()); fflush(stderr);
		LLMessageSystem* msg = gMessageSystem;
		msg->newMessageFast(_PREHASH_MapNameRequest);
		msg->nextBlockFast(_PREHASH_AgentData);
		msg->addUUIDFast(_PREHASH_AgentID, gAgent.getID());
		msg->addUUIDFast(_PREHASH_SessionID, gAgent.getSessionID());
		msg->addU32Fast(_PREHASH_Flags, 0x00000000); // no flags
		msg->addU32Fast(_PREHASH_EstateID, 0); // Filled in on sim
		msg->addBOOLFast(_PREHASH_Godlike, FALSE); // Filled in on sim
		msg->nextBlockFast(_PREHASH_NameData);
		msg->addStringFast(_PREHASH_Name, region_name.substr(1));
		gAgent.sendReliableMessage();
}

} // ns
