-- =================================================================
-- 🖼️ font_pipeline.lua (メイン/サブ設定完全連動・スマート解決版)
-- =================================================================

mcl_font_pipeline = {}

-- 1. settingtypes.txt / minetest.conf からの最新設定値安全ロード
local use_compat_mode    = core.settings:get_bool("mod_mcl_signs_char_image_file")
if use_compat_mode == nil then use_compat_mode = true end

local MAIN_ATLAS_PATTERN = core.settings:get("mod_mcl_signs_main_atlas_pattern") or "unicode_main%02x.png"
local MAIN_ATLAS_LIST    = core.settings:get("mod_mcl_signs_main_atlas_list") or "unicode_main.tsv"

-- サブアトラスのパターン。空（未設定）の場合はメイン側への一本化ルートが作動します
local SUB_ATLAS_PATTERN  = core.settings:get("mod_mcl_signs_sub_atlas_pattern")
if SUB_ATLAS_PATTERN == "" then SUB_ATLAS_PATTERN = nil end

local UAX11_WIDE         = core.settings:get_bool("mod_mcl_signs_uax11_wide", false)
if use_compat_mode then UAX11_WIDE = false end -- レガシー時のセーフティロック

local ATLAS_CHAR_W       = tonumber(core.settings:get("mod_mcl_signs_char_width")) or 12
local ATLAS_CHAR_H       = tonumber(core.settings:get("mod_mcl_signs_char_height")) or 12
local ATLAS_COLUMNS      = tonumber(core.settings:get("mod_mcl_signs_columns")) or 16

-- オフセット値の公開 (init.lua からの参照用)
local x_offset_setting               = core.settings:get("mod_mcl_signs_center_padding")
mcl_font_pipeline.GLOBAL_X_OFFSET    = tonumber(x_offset_setting) or 4

local y_offset_setting               = core.settings:get("mod_mcl_signs_y_offset")
mcl_font_pipeline.GLOBAL_Y_OFFSET    = tonumber(y_offset_setting) or 3

-- 下地ファイル名の安全生成（メインアトラスの0ページ目を動的参照）
mcl_font_pipeline.BASE_ATLAS_FILE    = string.format(MAIN_ATLAS_PATTERN, 0)

-- 内部基本設定
local mcl_font_config = {
	texture_suffix = ".png",
	fixed_width    = 6
}

-- メインアトラスに「実在する文字」を秒速判定するメモリハッシュテーブル
local main_atlas_registry = {}

-- 指定された MAIN_ATLAS_LIST (tsv) を起動時にパースする関数
local function build_main_atlas_registry()
	local modpath = core.get_modpath(core.get_current_modname())
	local tsv_path = modpath .. "/" .. MAIN_ATLAS_LIST
	
	local file = io.open(tsv_path, "r")
	if not file then
		core.log("action", "[mod_mcl_signs] Master list '" .. MAIN_ATLAS_LIST .. "' not found. Registry remains empty.")
		return
	end
	file:close()

	core.log("action", "[mod_mcl_signs] Loading font registry matrix from " .. MAIN_ATLAS_LIST .. "...")
	
	for line in io.lines(tsv_path) do
		if line ~= "" and not string.match(line, "^#") then
			local cp_str, page_hex = string.match(line, "([^\t]+)\t([^\t]+)")
			if cp_str and page_hex then
				local code = tonumber(cp_str) or tonumber(cp_str, 16)
				if code then
					main_atlas_registry[code] = string.lower(page_hex)
				end
			end
		end
	end
	core.log("action", "[mod_mcl_signs] Font registry matrix compiled. Fallback pipeline ready.")
end

-- 2. 共通全半角判定ロジック
local function is_halfwidth(code)
	if UAX11_WIDE then
		if code >= 0x0000 and code <= 0x007F then return true end
	else
		if code >= 0x0000 and code <= 0x04FF then return true end
	end
	if code >= 0xFF61 and code <= 0xFF9F then return true end
	return false
end

-- 3. メインとサブを自動判定して切り出す、16x16グリッド完全同期型エスケープスタンプ生成関数
function mcl_font_pipeline.get_external_atlas(code)
	local index = code % 256
	local col_index = index % ATLAS_COLUMNS
	local row_index = math.floor(index / ATLAS_COLUMNS)
	local grid_w = ATLAS_COLUMNS
	local grid_h = tonumber(core.settings:get("mod_mcl_signs_raw")) or 16

	local atlas_file
	local page = math.floor(code / 256)

	-- 💡 【方針を完全反映：サブアトラスの指定チェック】
	if not SUB_ATLAS_PATTERN then
		-- サブアトラス（フォールバック先）の指定が空（または紛失）の場合は、
		-- TSVリストの状態に一切関係なく、強制的にすべての文字を「メインアトラス（MAIN_ATLAS_PATTERN）」に一本化してルーティングします。
		atlas_file = string.format(MAIN_ATLAS_PATTERN, page)
	else
		-- サブアトラスの指定が有効な場合は、本来のWアトラス・動的フォールバック検索を実行
		local registered_page_hex = main_atlas_registry[code]
		if registered_page_hex then
			-- ⭕ メインに実在する：TSVから得た正確なページコードでメインアトラス名をビルド
			atlas_file = string.format(MAIN_ATLAS_PATTERN, tonumber(registered_page_hex, 16))
		else
			-- ❌ メインに無い（歯抜け）：自動的に指定されたサブアトラスのページを割り当て
			atlas_file = string.format(SUB_ATLAS_PATTERN, page)
		end
	end
	
	-- 修正済みのハット(\\^)とコロン(\\:)のエスケープ結合構文で安全に出力
	local tex_string = atlas_file .. "\\^[sheet\\:" .. grid_w .. "x" .. grid_h .. "\\:" .. col_index .. "," .. row_index
	local char_width = is_halfwidth(code) and 6 or 12
	
	return tex_string, char_width
end

-- 4. 【メインゲート】本家 charmap 連携 ＆ 3段階フォールバック解決
function mcl_font_pipeline.resolve_char(code, fallback_charmap)
	local current_charmap = fallback_charmap or _G.charmap or charmap or {}

	if use_compat_mode then
		if code >= 0x0500 then
			return mcl_font_pipeline.get_external_atlas(code)
		end

		local img_id = current_charmap[code]
		if img_id then
			local tex_file = img_id .. mcl_font_config.texture_suffix
			return tex_file, mcl_font_config.fixed_width
		end
		
		return mcl_font_pipeline.get_external_atlas(code)
	end

	return mcl_font_pipeline.get_external_atlas(code)
end

-- 5. 自動改行関数用の全半角ウェイト
function mcl_font_pipeline.get_char_weight(code)
	return is_halfwidth(code) and 1 or 2
end

-- 起動時にTSVマップを自動ビルド
build_main_atlas_registry()
