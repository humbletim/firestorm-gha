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
	void _htxhop_sendFlaglessMapNameRequest(std::string const& query_region_name) {
			LLMessageSystem* msg = gMessageSystem;
			msg->newMessageFast(_PREHASH_MapNameRequest);
			msg->nextBlockFast(_PREHASH_AgentData);
			msg->addUUIDFast(_PREHASH_AgentID, gAgent.getID());
			msg->addUUIDFast(_PREHASH_SessionID, gAgent.getSessionID());
			msg->addU32Fast(_PREHASH_Flags, 0x00000000); // no flags
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

	// PASSIVE INTEGRATION: here we capture references to LLWorldMapMessage
	// ephemeral (jury-rigged) name search privates...
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

	void _htxhop_sendExactNamedRegionRequest(_LLWorldMapMessageCapturedPrivates&& query) {
			auto const& key = extract_region(query.mSLURLRegionName);
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
			fprintf(stderr, "[xxHTxx] <<< Named Region '%s' (%s)\n", adopted.query_region_name.c_str(), adopted._extracted_region_name.c_str());fflush(stderr);
			// and finally send our own flagless MapNameRequest
			_htxhop_sendFlaglessMapNameRequest(adopted.query_region_name);
	}

	int _htxhop_query_process_block(_MapBlock const& _block) {
		if (_block.name.empty()) return 0;
		auto idx = _region_name_queries.find(extract_region(_block.name));
		if (idx != _region_name_queries.end()) {
			auto const& q = idx->second;
			fprintf(stderr, "[xxHTxx] >>> Named Region '%s' (%s) ==> '%s' %llu %s\n", q.query_region_name.c_str(), q._extracted_region_name.c_str(), _block.name.c_str(), _block.region_handle(), q.arbitrary_callback ? ".callback()" : "(orphaned request)");fflush(stderr);
			if (q.arbitrary_callback) q.arbitrary_callback(_block.region_handle(), q.arbitrary_slurl, _block.image_id, q.arbitrary_teleport);
			_region_name_queries.erase(idx);
			return 1;
		}
		if (_block.region_handle()) fprintf(stderr, "[xxHTxx] ... skip '%s' (%s) %llu\n", _block.name.c_str(), extract_region(_block.name).c_str(), _block.region_handle());fflush(stderr);
		return 0;
	}

	bool htxhop_processExactNamedRegionResponse(LLMessageSystem* msg, U32 agent_flags) {
		// NOTE: we assume only agent_flags have been read from msg so far
		S32 num_blocks = msg->getNumberOfBlocksFast(_PREHASH_Data);
		fprintf(stderr, "[xxHTxx] ... #blocks=%d #_region_name_queries=%lu agent_flags=%04x\n", num_blocks, _region_name_queries.size(), agent_flags);fflush(stderr);
		int resolved = 0;
		for (int block = 0; block < num_blocks; block++) {
			_MapBlock b{msg, block};
			fprintf(stderr, "[xxHTxx] %03d Named Region '%s' (%s)\n", b.block, b.name.c_str(), extract_region(b.name).c_str());fflush(stderr);
			resolved += _htxhop_query_process_block(b);
		}
		// for (auto const& kv : _region_name_queries) fprintf(stderr, "[xxHTxx] ... pending _region_name_queries[%s]=%p\n", kv.first.c_str(), &kv.second.arbitrary_callback);fflush(stderr);
		return resolved ? true : false;
	}

} // ns
