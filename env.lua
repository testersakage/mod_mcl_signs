-- env.lua

local Env = _G.SignEnv or {
	game_id = "unknown",	 -- "mineclonia", "voxelibre", "asuna", "exile", "minetest", "other"
	family = "unknown",	  -- "mcl", "mtg", "other"
	confidence = "none"
}

-- ゲームファミリー固有の本物のサウンドテーブル（C++オブジェクト）を格納する公開スロット
Env.sound_registry = {
	wood = {},
	iron = {}
}

-- -----------------------------------------------------------------------------
-- 1. 環境判別ロジック（4段階シグネチャ判定）
-- -----------------------------------------------------------------------------
local function detect_exact_environment()
	-- Exile (独自サバイバル系)
	if core.get_modpath("exile_game") or core.registered_nodes["exile_game:rock"] then
		Env.family = "other"
		Env.confidence = "exact (exile)"
		return "exile"
	end

	-- MCL系列 (Mineclonia vs VoxeLibre)
	local is_mcl_base = core.get_modpath("mcl_core") or core.registered_nodes["mcl_core:stone"]
	if is_mcl_base then
		Env.family = "mcl"

		if core.get_modpath("mcl_vl_entities_purge") 
		   or core.get_modpath("mcl_trial_spawners")
		   or core.get_modpath("mcl_vaults")
		   or core.get_modpath("mcl_tridents") then
			Env.confidence = "exact (mineclonia)"
			return "mineclonia"
		end

		if core.get_modpath("vl_env_sounds") or core.get_modpath("vl_legacy") then
			Env.confidence = "exact (mineclone2)"
			return "mineclone2"
		end

		Env.confidence = "fallback_mcl (voxelibre_compat)"
		return "mineclone2"
	end

	-- MTG系列 (Asuna vs 標準MTG)
	local is_mtg_base = core.get_modpath("default") or core.registered_nodes["default:stone"]
	if is_mtg_base then
		Env.family = "minetest"

		if core.get_modpath("asuna_core") or core.global_exists("asuna") then
			Env.confidence = "exact (asuna)"
			return "asuna"
		end

		Env.confidence = "exact (minetest)"
		return "minetest"
	end

	Env.family = "other"
	Env.confidence = "unknown"
	return "other"
end

Env.game_id = detect_exact_environment()

core.log("action", string.format("[SignEnv.Game] Environment Detected: '%s' | Family: '%s' (%s)", 
	Env.game_id, Env.family, Env.confidence))

_G.SignEnv = Env

return Env
