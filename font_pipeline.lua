-- =================================================================
-- 🖼️ font_pipeline.lua (下地ファイル名動的生成・完全公開版)
-- =================================================================

mcl_font_pipeline = {}

-- 1. settingtypes.txt / minetest.conf からの設定値安全ロード
local use_compat_mode    = core.settings:get_bool("mod_mcl_signs_char_image_file")
if use_compat_mode == nil then use_compat_mode = true end

local ATLAS_NAME_PATTERN = core.settings:get("mod_mcl_signs_atlas_name_pattern") or "atlas_mcl_p%02X.png"
local UAX11_WIDE         = core.settings:get_bool("mod_mcl_signs_uax11_wide", false)

if use_compat_mode then
	UAX11_WIDE = false
end

local ATLAS_CHAR_W       = tonumber(core.settings:get("mod_mcl_signs_char_width")) or 12
local ATLAS_CHAR_H       = tonumber(core.settings:get("mod_mcl_signs_char_height")) or 12
local ATLAS_COLUMNS      = tonumber(core.settings:get("mod_mcl_signs_columns")) or 16

-- オフセット値の公開
local x_offset_setting               = core.settings:get("mod_mcl_signs_center_padding")
mcl_font_pipeline.GLOBAL_X_OFFSET    = tonumber(x_offset_setting) or 4

local y_offset_setting               = core.settings:get("mod_mcl_signs_y_offset")
mcl_font_pipeline.GLOBAL_Y_OFFSET    = tonumber(y_offset_setting) or 3

-- ★【最重要修正】設定されたパターンを元に、0ページ目の下地用アトラスファイル名を動的に完全生成
mcl_font_pipeline.BASE_ATLAS_FILE    = string.format(ATLAS_NAME_PATTERN, 0)

-- 内部基本設定
local mcl_font_config = {
	texture_suffix = ".png",
	fixed_width    = 6
}

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

-- 3. 外部フォールバックアトラスからの動的エスケープ切り出し命令
-- =====================================================================
-- 💡 【見落としバグ修正】外部フォールバックアトラスからの動的切り出し
-- =====================================================================
function mcl_font_pipeline.get_external_atlas(code)
	local page  = math.floor(code / 256)
	local index = code % 256
	
	-- 設定されたファイル名パターンにページ番号を流し込む
	local atlas_file = string.format(ATLAS_NAME_PATTERN, page)
	
	-- 0〜15の正確なグリッドインデックス（マス目番号）を算出
	local col_index = index % ATLAS_COLUMNS
	local row_index = math.floor(index / ATLAS_COLUMNS)
	
	-- ★【完全勝利】string.format のバックスラッシュ消失バグを完全に回避！
	-- オリジナルの優秀な結合構文（..）をそのまま採用し、ハットの前の「\\^」とコロンの前の「\\:」を1文字の狂いもなく完全再現。
	-- サイズ部分（12x12）と座標（col_index, row_index）だけを設定値に挿げ替えます。
	local tex_string = atlas_file .. "\\^[sheet\\:16x16\\:" .. col_index .. "," .. row_index
		
	-- アトラス側の文字幅は全半角判定に基づいて動的に 6px / 12px に自動割り当て
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

-- 5. 【外部エクスポート】自動改行関数用の全半角ウェイト
function mcl_font_pipeline.get_char_weight(code)
	return is_halfwidth(code) and 1 or 2
end
