// potential workaround for hop://grid:port/Partial/x/y/z resolution
// 2024.04.30 humbletim

// notes:
//   - MapNameRequest's are sent flagless (0x0000, not using LAYER_FLAG)
//     - this is to avoid triggering OpenSim code paths that modify results
//       and make it impossible to discern Partial vs. Exact matching
//     - affects LLWorldMapMessage->sendNamedRegionRequest(name, callback, ...) 
// - meant to be gently wired into llworldmapmessage.cpp using
//   compile flags (/FI or -include) or a near-top #include <thisfile.c++>

#include <string>
#include <regex>

#include "llcommon.h"
#include "llsingleton.h"
#include "llworldmapmessage.h"
#include "message.h"
#include "llworldmap.h" // grid_to_region_handle
#include "llagent.h"

#include "llnotificationsutil.h"
#define htxhop_log(format, ...) { \
	fprintf(stderr, format "\n", __VA_ARGS__);fflush(stderr); \
	LLNotificationsUtil::add("ChatSystemMessageTip", LLSD().with("MESSAGE", llformat(format, __VA_ARGS__))); \
}

#include "llviewercontrol.h"

namespace {
	// decipher various hop Region Name embeddings
	inline std::string extract_region(std::string const& s) {
		static auto const& patterns = {
			std::regex{ R"(/ ([^/:=]+)$)" }, // TODO: figure out where the spec lives for hop "slash space" embedding...
			std::regex{ R"(([^/:=]+)$)" },   // TODO: figure out where the spec lives for hop "grid:port:region" embedding...
		};
		std::smatch match_results;
		std::string ls{s};
		LLStringUtil::toLower(ls);
		for (auto const& pattern : patterns) {
			if (std::regex_search(ls, match_results, pattern)) {
				return match_results[1].str();
			}
		}
		return {};
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
		S32 index{};
		U16 x_regions{}, y_regions{}, x_size{ REGION_WIDTH_UNITS }, y_size{ REGION_WIDTH_UNITS };
		std::string name{};
		U8 accesscode{};
		U32 region_flags{};
		LLUUID image_id{};

		inline U32 x_world() const { return (U32)(x_regions) * REGION_WIDTH_UNITS; }
		inline U32 y_world() const { return (U32)(y_regions) * REGION_WIDTH_UNITS; }
		inline U64 region_handle() const { return grid_to_region_handle(x_regions, y_regions); }

		_MapBlock(LLMessageSystem* msg, S32 block) : index(block) {
			// FIXME: this duplicates LLWorldMapMessage::processMapBlockReply...
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

	// like LLWorldMapMessage::sendNamedRegionRequest without flags=LAYER_FLAG
	void _htxhop_sendMapNameRequest(std::string const& query_region_name, U32 flags = 0x00000000) {
			LLMessageSystem* msg = gMessageSystem;
			msg->newMessageFast(_PREHASH_MapNameRequest);
			msg->nextBlockFast(_PREHASH_AgentData);
			msg->addUUIDFast(_PREHASH_AgentID, gAgent.getID());
			msg->addUUIDFast(_PREHASH_SessionID, gAgent.getSessionID());
			msg->addU32Fast(_PREHASH_Flags, flags);
			msg->addU32Fast(_PREHASH_EstateID, 0); // Filled in on sim
			msg->addBOOLFast(_PREHASH_Godlike, FALSE); // Filled in on sim
			msg->nextBlockFast(_PREHASH_NameData);
			msg->addStringFast(_PREHASH_Name, query_region_name);
			gAgent.sendReliableMessage();
	}

	// map extracted region names => pending query entries 
	struct _AdoptedRegionNameQuery {
		std::string query_region_name{};
		std::string arbitrary_slurl{}; 
		LLWorldMapMessage::url_callback_t arbitrary_callback{};
		bool arbitrary_teleport{ false };
		std::string _extracted_region_name{};
	};
	static std::map<std::string,_AdoptedRegionNameQuery> _region_name_queries{};

	// PASSIVE INTEGRATION: here we capture references to LLWorldMapMessage's
	// ephemeral (jury-rigged) name search privates.
	// + this strategy avoids changing upstream core header files
	// + and macro reduces necessary core change footprint even further 
	struct _LLWorldMapMessageCapturedPrivates {
		// note: all *references*
		std::string& mSLURLRegionName;
		std::string& mSLURL; 
		LLWorldMapMessage::url_callback_t& mSLURLCallback;
		bool& mSLURLTeleport;
	};
	#define htxhop_sendExactNamedRegionRequest(self) \
	 	_htxhop_sendExactNamedRegionRequest({ \
			self->mSLURLRegionName, \
			self->mSLURL, \
			self->mSLURLCallback, \
			self->mSLURLTeleport \
		})

	static LLCachedControl<S32> htxhop_flags(gSavedSettings, "htxhop_flags", 0, "default: 0\nLAYER_FLAG: 2\n");
	bool _htxhop_sendExactNamedRegionRequest(_LLWorldMapMessageCapturedPrivates&& query) {
			if (+htxhop_flags == 2) {
				return false;
			}
			auto const& key = extract_region(query.mSLURLRegionName);
			if (key.empty()) return false;
			// first adopt into our explicitly pending queue
			_region_name_queries[key] = { query.mSLURLRegionName, query.mSLURL, query.mSLURLCallback, query.mSLURLTeleport, key };
			// then reset to prevent any original implicit handling
			{
				query.mSLURLCallback = NULL;
				query.mSLURLRegionName.clear();
				query.mSLURL.clear();
				query.mSLURLTeleport = false;
			}

			auto const& adopted = _region_name_queries[key];
			htxhop_log("[xxHTxx] Send Region Name '%s' (key: %s)", adopted.query_region_name.c_str(), adopted._extracted_region_name.c_str());
			// and finally send our own flagless MapNameRequest
			_htxhop_sendMapNameRequest(adopted.query_region_name, +htxhop_flags);
			return true;
	}

	bool htxhop_processExactNamedRegionResponse(LLMessageSystem* msg, U32 agent_flags) {
		if (+htxhop_flags == 2) {
			return false;
		}
		// NOTE: we assume only agent_flags have been read from msg so far
		S32 num_blocks = msg->getNumberOfBlocksFast(_PREHASH_Data);

		std::vector<_MapBlock> blocks;
		blocks.reserve(num_blocks);
		for (int b = 0; b < num_blocks; b++) {
			blocks.emplace_back(msg, b);
		}
		for (auto const& _block : blocks) {
			htxhop_log("#%02d key='%s' block.name='%s' block.region_handle=%llu", _block.index, extract_region(_block.name).c_str(), _block.name.c_str(), _block.region_handle());
		}

		// handle special case of a "redirect" response (region handle available on first result)
		auto redirect = blocks.size() == 2 && !blocks[1].region_handle() && blocks[0].region_handle() && extract_region(blocks[0].name).empty();
		if (redirect && _region_name_queries.size() == 1) {
			htxhop_log("applying first block as redirect; region_handle: %llu", blocks[0].region_handle());
			blocks[0].name = _region_name_queries.begin()->second.query_region_name;
		}
		for (auto const& _block : blocks) {
			auto key = extract_region(_block.name);
			if (key.empty()) continue;
			auto idx = _region_name_queries.find(key);
			if (idx != _region_name_queries.end()) {
				auto pending = idx->second;
				htxhop_log("[xxHTxx] Recv Region Name '%s' (key: %s) block.name='%s' block.region_handle=%llu)", pending.query_region_name.c_str(), pending._extracted_region_name.c_str(), _block.name.c_str(), _block.region_handle());
				_region_name_queries.erase(idx);
				pending.arbitrary_callback(_block.region_handle(), pending.arbitrary_slurl, _block.image_id, pending.arbitrary_teleport);
				return true;
			}
		}
		return false;
	}

} // ns
