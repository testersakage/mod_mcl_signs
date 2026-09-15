-- mod_mcl_signs/init.lua

mod_mcl_signs = {}

local modname = core.get_current_modname()

local S = core.get_translator(modname)
local modpath = core.get_modpath(modname)

local Arbitrator = _G.SignArbitrator or dofile(modpath .. "/arbitrator.lua") -- 調停
local Env        = _G.SignEnv        or dofile(modpath .. "/env.lua") -- 調査

mod_mcl_signs.Arbitrator = Arbitrator

-- SignEnv の判定結果に基づき JSON パスを決定
local json_filename = Env.game_id .. ".json"
local json_path = modpath .. "/games/" .. json_filename

local function load_json_config(path)
	local file = io.open(path, "r")
	if not file then return nil end
	local content = file:read("*all")
	file:close()
	return core.parse_json(content)
end

-- 設定ファイルのロード（見つからない場合は minetest.json へフォールバック）
local json_config = load_json_config(json_path)
if not json_config then
	core.log("action", "[mod_mcl_signs] No configuration found for game '" .. Env.game_id .. "'. Falling back to minetest.json")
	json_path = modpath .. "/games/minetest.json"
	json_config = load_json_config(json_path)
else
	core.log("action", "[mod_mcl_signs] Loading sign configuration for game: " .. Env.game_id)
end

if not json_config or type(json_config) ~= "table" then
	core.log("error", "[mod_mcl_signs] Critical Error: Failed to load or parse JSON config from: " .. json_path)
	return
end

-- 調停エンジンにmodを登録
mod_mcl_signs.Arbitrator.register_engine("mod_mcl_signs", {
	entity_name = "mod_mcl_signs:text",
	on_restore = function(pos, node, sign_id)
		-- 登録された瞬間に、描画関数をキック
		core.after(0, function()
			mod_mcl_signs.update_sign(pos)
		end)
	end
})

if json_config and json_config.legacy_hooks then
	-- arbitrator.lua 抽象化フック実行エンジンをキック
	mod_mcl_signs.Arbitrator.apply_system_arbitration(json_config.legacy_hooks)
end

-- コピーした独自UTF-8ライブラリ (utf8.lua) を安全に読み込む
local utf8 = dofile(modpath .. "/utf8.lua")

-- 万が一読み込めなかった場合や、ファイルがテーブルを返さなかった場合のフォールバック対策
if type(utf8) ~= "table" then
	utf8 = _G.utf8 or {}
end

-- table.merge が存在しない場合のフォールバック定義
if not table.merge then
	table.merge = function(t1, t2, t3, t4)
		local result = {}
		if t1 then			for k, v in pairs(t1) do result[k] = v end		end
		if t2 then			for k, v in pairs(t2) do result[k] = v end		end
		if t3 then			for k, v in pairs(t3) do result[k] = v end		end
		if t4 then			for k, v in pairs(t4) do result[k] = v end		end
		return result
	end
end

dofile(modpath .. "/font_pipeline.lua") -- 追加

-- Character map (see API.md for reference)
--local charmap = {}
mod_mcl_signs.charmap = {}
for line in io.lines(modpath .. DIR_DELIM .. "characters.tsv") do
	local split = line:split("\t")
	if #split == 3 then
		local char, img, _ = split[1], split[2], split[3] -- 3rd is ignored, reserved for width
		local code = utf8.codepoint(char)
		mod_mcl_signs.charmap[code] = img
	end
end

local signs_editable = core.settings:get_bool("mcl_signs_editable", false)

local SIGN_WIDTH = 115

local LINE_LENGTH = 15
local NUMBER_OF_LINES = 4

local LINE_HEIGHT = 14
local CHAR_WIDTH = 5

local SIGN_GLOW_INTENSITY = 14

local NEWLINE = {
	[0x000A] = true,	[0x000B] = true,	[0x000C] = true,
	-- U+000D (CR) is dropped on U-string conversion
	[0x0085] = true,	[0x2028] = true,	[0x2029] = true,
}

local WHITESPACE = {
	[0x0009] = true,	[0x0020] = true,
	-- U+00A0 is a whitespace, but a non-breaking one
	[0x1680] = true,	[0x2000] = true,	[0x2001] = true,	[0x2002] = true,
	[0x2003] = true,	[0x2004] = true,	[0x2005] = true,	[0x2006] = true,
	-- U+2007 is a whitespace, but a non-breaking one
	[0x2008] = true,	[0x2009] = true,	[0x200A] = true,
	-- U+202F is a whitespace, but a non-breaking one
	[0x205F] = true,	[0x3000] = true,
}

local HYPHEN = {
	[0x002D] = true,	[0x00AD] = true,	[0x058A] = true,
	[0x05BE] = true,	[0x1806] = true,	[0x2010] = true,
	-- U+2011 is a hyphen, but a non-breaking one
	[0x2E17] = true,	[0x2E5D] = true,	[0x30FB] = true,
	[0xFE63] = true,	[0xFF0D] = true,	[0xFF65] = true,
}

local CR_CODEPOINT = utf8.codepoint("\r") -- ignored
local WRAP_CODEPOINT = utf8.codepoint("‐") -- default, ellipsis for "truncate"

local DEFAULT_COLOR = "#000000"

local F = core.formspec_escape

-- Template definition
local sign_config_tpl = json_config and json_config.node_template or {}
local sign_tpl = table.copy(sign_config_tpl)

if sign_tpl.locale and type(sign_tpl.locale) == "table" then
	for key, raw_text in pairs(sign_tpl.locale) do
		if type(raw_text) == "string" then
			local args = raw_text:find("@") and { NUMBER_OF_LINES or 4, LINE_LENGTH or 15 } or {}
			sign_tpl[key] = S(raw_text, unpack(args))
			if key == "_tt_help" then
				local col_gray = "\x1b(c@#7f7f7f)"
				local col_reset = "\x1b(c@R)"
--				sign_tpl[key] = sign_tpl[key] .. "\n" .. col_gray .. "[Extra System]\n" .. col_gray .. "  Font Atlas Render\n" .. col_gray .. "  Arbitrator Sign" .. col_reset
			end
		end
	end
	sign_tpl.locale = nil -- データ清掃
end

-- 追加設定（サウンド）
if _G[json_config.sound_mod] and _G[json_config.sound_mod][json_config.sound_obj] then
    sign_tpl.sounds = _G[json_config.sound_mod][json_config.sound_obj]()
else
    sign_tpl.sounds = {}
end
-- 追加設定（ツールチップ）
if sign_tpl._tt_help then
	sign_tpl._tt_help = sign_tpl._tt_help .. "\n+Signboard Arbitrator\n+Font Atlas Renderer"
end

-- Signs data / meta
local function normalize_rotation(rot)
	return math.floor(0.5 + rot / 15) * 15
end

local function get_signdata(pos)
	local node = core.get_node(pos)
	local def = core.registered_nodes[node.name]
	if not def or core.get_item_group(node.name, "sign") < 1 then return end

	local meta = core.get_meta(pos)
	local text = core.deserialize(meta:get_string("utext"), true) or {}
	local color = meta:get_string("color")
	if color == "" then
		color = DEFAULT_COLOR
	end
	local glow = core.is_yes(meta:get_string("glow"))

	local yaw, spos
	local typ = "standing"
	if def.paramtype2  == "wallmounted" then
		typ = "wall"
		local dir = core.wallmounted_to_dir(node.param2)
		spos = vector.add(vector.offset(pos, 0, -0.25, 0), dir * 0.41)
		yaw = core.dir_to_yaw(dir)
	elseif def.paramtype2 == "4dir" then
		typ = "hanging"
		local dir = core.fourdir_to_dir (node.param2)
		spos = vector.add (vector.offset (pos,0,-0.45,0), dir * -0.075)
		yaw = core.dir_to_yaw (dir)
	elseif def.groups.hanging_sign and def.groups.hanging_sign >= 1 then
		yaw = math.rad(((node.param2 * 1.5 ) + 1 ) % 360)
		local dir = core.yaw_to_dir(yaw)
		spos = vector.add(vector.offset(pos,0,-0.45,0),dir * -0.075)
	else
		yaw = math.rad(((node.param2 * 1.5) + 1) % 360)
		local dir = core.yaw_to_dir(yaw)
		spos = vector.add(vector.offset(pos, 0, 0.08, 0), dir * -0.05)
	end

	return {
		text = text,
		color = color,
		yaw = yaw,
		node = node,
		typ = typ,
		glow = glow,
		text_pos = spos,
	}
end

local function set_signmeta(pos, tbl)
	local meta = core.get_meta(pos)
	if tbl.text then meta:set_string("utext", core.serialize(tbl.text)) end
	if tbl.color then meta:set_string("color", tbl.color) end
	if tbl.glow then meta:set_string("glow", tbl.glow) end
end

-- Text processing
function mod_mcl_signs.string_to_ustring(str, max_characters)
	-- limit saved text to 256 characters by default
	-- (4 lines x 15 chars = 60 so this should be more than is ever needed)
	max_characters = max_characters or 256

	local ustr = {}

	-- utf8ライブラリが利用可能かチェックし、安全にループ処理を行う
	local u8 = utf8 or string
	if u8 and u8.codes then
		for i, code in u8.codes(str) do
			if i >= max_characters or code == CR_CODEPOINT then
				break
			end
			table.insert(ustr, code)
		end
	else
		-- 環境にutf8ライブラリがない場合のフォールバック（バイト単位で処理）
		for i = 1, #str do
			if i >= max_characters then break end
			local code = string.byte(str, i)
			if code == CR_CODEPOINT then break end
			table.insert(ustr, code)
		end
	end

	return ustr
end

local function ustring_to_string(ustr)
	local str = ""
	for _, code in ipairs(ustr) do
		str = str .. utf8.char(code)
	end
	return str
end

-- TODO: make shared code as table.slice()?
local function subseq(ustr, s, e)
	local line = {}
	for i = s, e do
		line[#line+1] = ustr[i]
	end
	return line
end

-- =====================================================================
-- 2. 自動折り返し（改行）判定関数 (新モジュールの全半角ウェイトに結合)
-- =====================================================================
function ustring_to_line_array(ustr)
	local lines = {}
	local start, stop = 1, 1
	local current_line_length = 0

	for cursor, code in ipairs(ustr) do
		if #lines >= NUMBER_OF_LINES then break end
		if WHITESPACE[code] or HYPHEN[code] then stop = cursor end

		if NEWLINE[code] then
			table.insert(lines, subseq(ustr, start, cursor - 1))
			start, stop = cursor + 1, cursor + 1
			current_line_length = 0
		else
			-- パイプライン側から、正確な全半角ウェイト（1 または 2）を取得して加算
			local weight = mcl_font_pipeline.get_char_weight(code)
			
			if current_line_length + weight >= 16 then
				if stop <= start then 
					local line = subseq(ustr, start, cursor - 1)
					table.insert(line, WRAP_CODEPOINT)
					table.insert(lines, line)
					start, stop = cursor, cursor
				else
					table.insert(lines, subseq(ustr, start, stop + (HYPHEN[ustr[stop]] and 0 or -1)))
					start, stop = stop + 1, stop + 1
				end
				current_line_length = weight
			else
				current_line_length = current_line_length + weight
			end
		end
	end

	if #lines < NUMBER_OF_LINES and start <= #ustr then
		table.insert(lines, subseq(ustr, start, #ustr))
	end

	return lines
end

-- =====================================================================
-- 3. 行テクスチャ生成関数 (下地スタンプの設定連動修正版)
-- =====================================================================
local function generate_line(ustr, lineno, line_width, line_height, default_char_width)
	local texture = ""
	local width = 0
	local maxw = 0
	local chars = {}
	local ch_offs = 0

	for _, code in ipairs(ustr) do
		if code == 0x0A or code == 0x0D or code < 32 or (code >= 127 and code <= 159) then
			code = 32
		end

		local tex, w = mcl_font_pipeline.resolve_char(code, mod_mcl_signs.charmap)

		width = width + w
		maxw = math.max(width, maxw)
		
		table.insert(chars, { off = ch_offs, tex = tex, w = w })
		ch_offs = ch_offs + w
	end

	-- GLOBAL_X_OFFSET による中央寄せ調整
	local start_xpos = math.max(0, math.floor((line_width - maxw) / 2)) + mcl_font_pipeline.GLOBAL_X_OFFSET
	local end_xpos = math.min(start_xpos + maxw, line_width)
	local xpos = start_xpos

	-- GLOBAL_Y_OFFSET による行高さ調整
	local ypos = line_height * lineno + mcl_font_pipeline.GLOBAL_Y_OFFSET

	-- 二重配置スタンプによるハック描画（C++パーサー完全適合仕様）
	for _, ch in ipairs(chars) do
		if xpos + ch.off > line_width then break end
		local current_x = xpos + ch.off
		
		-- ★【バグ完全修正】固定のファイル名を撤去し、設定から動的に生成された BASE_ATLAS_FILE を適用！
		texture = texture .. (":%d,%d=%s\\^[sheet\\:16x16\\:0,2"):format(current_x, ypos, mcl_font_pipeline.BASE_ATLAS_FILE)
		
		-- 本番の文字テクスチャスタンプ
		texture = texture .. (":%d,%d=%s"):format(current_x, ypos, ch.tex)
	end
	return texture
end

function generate_texture(data)
	local lines = ustring_to_line_array(data.text)
	local line_width = SIGN_WIDTH
	
	-- 行ピッチの12px等幅適正化
	local line_height = LINE_HEIGHT
	if line_height < 12 then line_height = 12 end

	local default_char_width = CHAR_WIDTH + 1
	local letter_color = data.color or DEFAULT_COLOR

	-- 大枠となる [combine 命令の器を初期化
	local texture = { ("[combine:%dx%d"):format(line_width, line_width) }
	local lineno = 0
	for i = 1, #lines do
		local linetex = generate_line(lines[i], lineno, line_width, line_height, default_char_width)
		table.insert(texture, linetex)
		lineno = lineno + 1
	end
	
	local combined_tex = table.concat(texture, "")
	
	-- カラー乗算（multiply）を適用
	combined_tex = "(" .. combined_tex .. "^[multiply:" .. letter_color .. ")"
--	minetest.log("action", "[mod_mcl_signs]  -> " .. combined_tex)
	
	return combined_tex
end

-- Text entity handling
function mod_mcl_signs.get_text_entity(pos, force_remove)
	local objects = core.get_objects_inside_radius(pos, 0.5)
	local text_entity
	local i = 0
	for _, v in pairs(objects) do
		local ent = v:get_luaentity()
		if ent and ent.name == "mod_mcl_signs:text" then
			i = i + 1
			if i > 1 or force_remove == true then
				v:remove()
			else
				text_entity = v
			end
		end
	end
	return text_entity
end

-- Update the sign text entity (create if doesn't exist)
function mod_mcl_signs.update_sign(pos)
	local data = get_signdata(pos)

	-- 先ほど書き換えた関数名に修正
	local text_entity = mod_mcl_signs.get_text_entity(pos)
	if text_entity and not data then
		text_entity:remove()
		return false
	elseif not data then
		return false
	elseif not text_entity then
		text_entity = core.add_entity(data.text_pos, "mod_mcl_signs:text")
		if not text_entity or not text_entity:get_pos() then return end
	end

	-- 文字エンティティへ、ノードの sign_id を1対1で保存
	local current_sign_id = mod_mcl_signs.Arbitrator.get_or_create_sign_id(pos)
	
	local ent = text_entity:get_luaentity()
	if ent then
		ent.sign_id = current_sign_id
	end

	text_entity:set_properties({
		textures = {generate_texture(data)},
		-- SIGN_GLOW_INTENSITY が未定義でエラーが出る場合は 14 に置き換えてください
		glow = data.glow and (SIGN_GLOW_INTENSITY or 14) or 0,
	})
	text_entity:set_yaw(data.yaw)
	text_entity:set_armor_groups({immortal = 1})
	return true
end

-- Text entity definition
core.register_entity("mod_mcl_signs:text", {
	initial_properties = {
		pointable = false,
		visual = "upright_sprite",
		physical = false,
		collide_with_objects = false,
	},
	
	-- 自己スキャンして不整合があれば、その場で自発的に消滅。
	on_activate = function(self, staticdata, dtime)
		-- 1. セーブデータ（staticdata）から、過去に保存されていた sign_id の復元を試みる
		if staticdata and staticdata ~= "" then
			local s_data = core.deserialize(staticdata)
			if type(s_data) == "table" and s_data.sign_id then
				self.sign_id = s_data.sign_id
			end
		end

		-- 2. テクスチャの生存指紋チェック
		local props = self.object:get_properties()
		local t = props and props.textures
		if type(t) ~= "table" or #t == 0 then 
			self.object:remove() 
			return
		end
	end,

	-- サーバーが保存される瞬間に、自分の sign_id をセーブ
	get_staticdata = function(self)
		return core.serialize({ sign_id = self.sign_id })
	end,
})

-- Formspec
local function show_formspec(player, pos)
	if not pos then return end
	local meta = core.get_meta(pos)
	local old_text = ustring_to_string(core.deserialize(meta:get_string("utext"), true) or {})
	local fs = {
		"size[6,3]textarea[0.25,0.25;6,1.5;text;",
		F(S("Enter sign text:")), ";", F(old_text), "]",
		"label[0,1.5;",
			F(S("Maximum line length: @1", LINE_LENGTH)), "\n",
			F(S("Maximum lines: @1", NUMBER_OF_LINES)),
		"]",
		"button_exit[0,2.4;6,1;submit;", F(S("Done")), "]"
	}
	core.show_formspec(player:get_player_name(), "mod_mcl_signs:set_text_"..pos.x.."_"..pos.y.."_"..pos.z, table.concat(fs))
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname:find("mod_mcl_signs:set_text_") == 1 then
		local x, y, z = formname:match("mod_mcl_signs:set_text_(.-)_(.-)_(.*)")
		local pos = vector.new(tonumber(x), tonumber(y), tonumber(z))
		if not fields or not fields.text then return end
		
		-- Mineclonia固有の保護チェックを、Luanti標準の保護チェック (core.is_protected) に書き換え
		local name = player:get_player_name()
		local is_protected = core.is_protected(pos, name)
		
		if not is_protected and (signs_editable or core.get_meta(pos):get_string("text") == "") then
			-- 関数名を mod_mcl_signs に修正
			local utext = mod_mcl_signs.string_to_ustring(fields.text)
			set_signmeta(pos, {text = utext})
			-- 関数名を mod_mcl_signs に修正
			mod_mcl_signs.update_sign(pos)
		end
	end
end)

local unlimited_player_transfer_distance = core.settings:get_bool("unlimited_player_transfer_distance", true)
local player_transfer_distance = unlimited_player_transfer_distance and 0 or tonumber(core.settings:get("player_transfer_distance")) or 0

-- Mineclonia固有の「mcl_hand_range_creative」を、標準の「hand_range」設定またはデフォルト値10に置き換え
local hand_range_creative = tonumber(core.settings:get("hand_range")) or 10
local max_close_formspec_range = math.min(hand_range_creative + 1, player_transfer_distance > 0 and player_transfer_distance or math.huge)

function mod_mcl_signs.close_formspec(pos)
	-- core.get_connected_players() でサーバー内の全プレイヤーを取得し、距離を判定する
	for _, player in pairs(core.get_connected_players()) do
		local p_pos = player:get_pos()
		if p_pos and vector.distance(pos, p_pos) <= max_close_formspec_range then
			core.close_formspec(player:get_player_name(),
				"mod_mcl_signs:set_text_" .. pos.x .. "_" .. pos.y .. "_" .. pos.z)
		end
	end
end

local function project_placer_dir (axis, placer_dir)
	local axis_1 = vector.normalize (vector.new (axis.z, 0, axis.x))
	local dot = vector.dot (axis_1, placer_dir)
	return vector.multiply (axis_1, dot ~= 0.0 and dot or 1.0)
end

-- Mineclonia固有の分解関数を使わず、標準のフルブロックのAABB定義を直接テーブルとして定義する
local FULL_BLOCK = {
	{
		-0.5, -0.5, -0.5,
		0.5, 0.5, 0.5,
	},
}

-- Node definition callbacks
function sign_tpl.on_place(itemstack, placer, pointed_thing)
	-- Mineclonia固有の関数をLuanti標準の右クリック判定 (core.item_place) 互換の仕組みに修正
	-- 設置先ブロック（チェストや扉など）に右クリック処理があればそれを優先する
	local node_under = core.get_node(pointed_thing.under)
	local def_under = core.registered_nodes[node_under.name]
	if def_under and def_under.on_rightclick and not (placer and placer:get_player_control().sneak) then
		return def_under.on_rightclick(pointed_thing.under, node_under, placer, itemstack, pointed_thing)
	end

	local under = pointed_thing.under
	local above = pointed_thing.above
	local dir = vector.subtract(under, above)
	local wdir = core.dir_to_wallmounted(dir)

	-- Signs can be attached to walkable nodes and other signs.
	local node = core.get_node(under)
	local ndef = core.registered_nodes[node.name]

	-- If pointed at node is buildable_to we instead check node behind
	-- (which is the node core.item_place_node will attach the sign to).
	if ndef and ndef.buildable_to then
		under = vector.add(under, dir)
		node = core.get_node(under)
		ndef = core.registered_nodes[node.name]
	end

	if not ndef or (not ndef.walkable and core.get_item_group(node.name, "sign") == 0) then
		return itemstack
	end

	local itemstring = itemstack:get_name()
	local def = itemstack:get_definition()
	-- 木の種類を特定するための内部変数のプレフィックスを _mod_mcl_ に統一（未定義なら "oak" などをフォールバックに）
	local sign_wood = def._mod_mcl_sign_wood or def._mcl_sign_wood or "oak"

	local pos
	local placestack = ItemStack(itemstack)
	if core.get_item_group (itemstring, "hanging_sign") == 0 then
		if wdir < 1 then
			-- no placement on ceilings allowed yet
			return itemstack
		elseif wdir == 1 then
			placestack:set_name("mod_mcl_signs:standing_sign_"..sign_wood)
			-- param2 value is degrees / 1.5
			local rot = normalize_rotation(placer:get_look_horizontal() * 180 / math.pi / 1.5)
			itemstack, pos = core.item_place_node(placestack, placer, pointed_thing, rot)
		else
			placestack:set_name("mod_mcl_signs:wall_sign_"..sign_wood)
			itemstack, pos = core.item_place_node(placestack, placer, pointed_thing, wdir)
		end
	else
		-- Hanging sign.
		if wdir == 0 then
			if not ndef.walkable and core.get_item_group(node.name, "sign") == 0 then
				return itemstack
			end

			local is_full_bottom = false

			-- 取付先がすでに看板(hanging_sign等)である場合
			if core.get_item_group(node.name, "sign") ~= 0 then
				is_full_bottom = false
			-- 標準的なフルキューブブロック(drawtypeがnormal、またはnode_box未定義かつmesh未使用)
			elseif ndef.drawtype == "normal" or (not ndef.node_box and not ndef.mesh) then
				is_full_bottom = true
			-- node_boxが明示的に設定されている場合
			elseif ndef.node_box and ndef.node_box.type == "fixed" then
				local box = ndef.node_box.fixed
				-- 単一ボックスの場合の判定
				if type(box[1]) == "number" then
					if box[1] <= -0.5 and box[2] <= -0.5 and box[3] <= -0.5 and
					   box[4] >= 0.5 and box[6] >= 0.5 then
						is_full_bottom = true
					end
				-- 複数ボックスで構成されている場合
				elseif type(box[1]) == "table" then
					for _, b in ipairs(box) do
						if b[1] <= -0.5 and b[2] <= -0.5 and b[3] <= -0.5 and
						   b[4] >= 0.5 and b[6] >= 0.5 then
							is_full_bottom = true
							break
						end
					end
				end
			end

			if is_full_bottom then
				local dir = vector.subtract (above, placer:get_pos ())
				local fourdir = core.dir_to_fourdir (dir)
				placestack:set_name ("mod_mcl_signs:hanging_sign_" .. sign_wood)
				itemstack, pos = core.item_place_node (placestack, placer, pointed_thing, fourdir)
			else
				local rot = normalize_rotation(placer:get_look_horizontal() * 180 / math.pi / 1.5)
				placestack:set_name ("mod_mcl_signs:hanging_sign_attached_" .. sign_wood)
				itemstack, pos = core.item_place_node (placestack, placer, pointed_thing, rot)
			end
		elseif wdir ~= 1 then
			local placer_dir = vector.subtract (above, placer:get_pos ())
			local dir = project_placer_dir (dir, vector.normalize (placer_dir))
			local fourdir = core.dir_to_fourdir (dir)
			placestack:set_name ("mod_mcl_signs:hanging_sign_wall_" .. sign_wood)
			itemstack, pos = core.item_place_node (placestack, placer, pointed_thing,
							       fourdir)
		else
			return itemstack
		end
	end

	show_formspec(placer, pos)
	-- restore canonical name as core.item_place_node might have changed it
	itemstack:set_name(itemstring)
	return itemstack
end

-- アイテムから適用すべきカラーコードをJSONから直接取得するヘルパー関数
local function get_color_from_dye(item_name)
	if json_config.sign_dye_code and json_config.sign_dye_code[item_name] then
		local code = json_config.sign_dye_code[item_name]
		-- 頭に '#' がついていない場合は付与する
		if string.sub(code, 1, 1) ~= "#" then
			code = "#" .. code
		end
		return code -- カラーコード（例: "#ffffff"）を返す
	end
	return nil
end

-- アイテムが発光アイテムとしてJSONに登録されているかチェックするヘルパー関数
local function is_glow_item(item_name)
	if not json_config.glow_sign_item or type(json_config.glow_sign_item) ~= "table" then
		return false
	end

	for _, glow_item in ipairs(json_config.glow_sign_item) do
		if item_name == glow_item then
			return true
		end
	end
	return false
end

function sign_tpl.on_rightclick(pos, _, clicker, itemstack, _)
	local item_name = itemstack:get_name()
	local player_name = clicker:get_player_name()
	
	local has_glow_effect = is_glow_item(item_name)
	local dye_color_code = get_color_from_dye(item_name)

	-- 染料または発光アイテムが使われた場合の処理
	if has_glow_effect or dye_color_code then
		local data = get_signdata(pos)
		if data then
			local next_glow = data.glow or "false"
			local next_color = data.color or "#ffffff"
			
			if has_glow_effect then
				if next_color == "#000000" then
					next_color = "#7e7e7e" -- 黒は暗闇で見えなくなるため補正
				end
				next_glow = "true"
			elseif dye_color_code then
				next_color = dye_color_code
			end
			
			set_signmeta(pos, {glow = next_glow, color = next_color})
			mod_mcl_signs.update_sign(pos)
			
			if not core.is_creative_enabled(player_name) then
				itemstack:take_item()
			end
			return itemstack
		end
		
	elseif signs_editable then
		-- 通常の編集画面表示（保護チェック付き）
		if not core.is_protected(pos, player_name) then
			show_formspec(clicker, pos)
		end
	end
	
	return itemstack
end

function sign_tpl.on_destruct(pos)
	mod_mcl_signs.get_text_entity(pos, true)
	mod_mcl_signs.close_formspec(pos)
end

function sign_tpl._on_dye_place(pos, color)
	-- 定義がない色の場合はデフォルトとして白 (#ffffff) にフォールバック
	local rgb_color = json_config.sign_dye_code["mcl_dyes:" .. color] or "#ffffff"
	if string.sub(rgb_color, 1, 1) ~= "#" then
		rgb_color = "#" .. rgb_color
	end

	set_signmeta(pos, { color = rgb_color })
	mod_mcl_signs.update_sign(pos)
end

-- Wall sign definition
local wall_config_tpl = json_config and json_config.wall_template or {}
local sign_wall = table.merge(sign_tpl, wall_config_tpl)

local function colored_texture(texture, color)
	return texture.."^[multiply:"..color
end

function mod_mcl_signs.register_sign(name, color, def)
	-- アンダースコアをスペースに置き換えてから、各単語の頭文字を大文字にする処理
	local title_name = name:gsub("_", " "):gsub("(%a)([%w_']*)", function(first, rest)
		return first:upper() .. rest:lower()
	end)

	-- 1. 共通のフィールド設定
	local newfields = {
		description = S(title_name .. " Sign"), 
		tiles = {colored_texture("mcl_signs_sign_greyscale.png", color)},
		inventory_image = colored_texture("mcl_signs_default_sign_greyscale.png", color),
		wield_image = colored_texture("mcl_signs_default_sign_greyscale.png", color),
		
		-- 重要: 破壊時にドロップするアイテムを「立て看板 (standing_sign)」に統一
		drop = "mod_mcl_signs:standing_sign_"..name,
		
		_mod_mcl_sign_wood = name,
--		_mcl_sign_wood = name,
	}

	def = def or {}
	
	-- 2. 立て看板 (Standing Sign) の登録
	-- 【調停インフラのドッキング】：
	-- core.register_node を捨て、 Arbitrator ヘルパーへパスを回す
	-- これにより、設置時（on_construct）にノードへの 'sign_id' メタデータの刻印が100%確定
	local node_name_standing = ":mod_mcl_signs:standing_sign_" .. name
	local node_def_standing = table.merge(sign_tpl, newfields, def)
	
	mod_mcl_signs.Arbitrator.register_sign_node(node_name_standing, "mod_mcl_signs", node_def_standing)
	
	
	-- 3. 壁掛け看板 (Wall Sign) の登録
	-- 壁掛け用のテーブルをマージしつつ、インベントリ非表示グループを強制追加
	local wall_fields = table.merge(newfields, {
		groups = table.merge(sign_wall.groups, { not_in_creative_inventory = 1 })
	})
	
	local node_name_wall = ":mod_mcl_signs:wall_sign_" .. name
	local node_def_wall = table.merge(sign_wall, wall_fields, def)
	
	-- 壁掛け側も、 Arbitrator ヘルパーでインド
	mod_mcl_signs.Arbitrator.register_sign_node(node_name_wall, "mod_mcl_signs", node_def_wall)
end

local h_config_tpl   = json_config and json_config.hanging_template or {}
local h_wall_config  = json_config and json_config.hanging_wall_template or {}
local h_attach_config = json_config and json_config.hanging_attached_template or {}

local sign_hanging          = table.merge(sign_tpl, h_config_tpl)
local sign_hanging_wall     = table.merge(sign_tpl, h_wall_config)
local sign_hanging_attached = table.merge(sign_tpl, h_attach_config)

-- 関数名を mod_mcl_signs に修正
function mod_mcl_signs.register_hanging_sign (name, def)
	local title_name = name:gsub("^%l", string.upper)

	local newfields = {
		description = S("Hanging " .. title_name .. " Sign"),
		inventory_image = "mcl_signs_hanging_sign_" .. name .. "_item.png",
		wield_image = "mcl_signs_hanging_sign_" .. name .. "_item.png",
		drop = "mcl_signs:hanging_sign_" .. name,
		
		-- 設置処理 (on_place) の互換性のために両方の変数を保持
		_mod_mcl_sign_wood = name,
--		_mcl_sign_wood = name,
	}
	
	def = def or {}

	-- 1. 通常の吊り下げ看板 (Hanging Sign) の登録
	local node_name_normal = ":mod_mcl_signs:hanging_sign_" .. name
	local node_def_normal = table.merge(sign_hanging, newfields, {
		tiles = { "mcl_signs_hanging_sign_" .. name .. ".png" },
	}, def)
	-- 【調停インフラのドッキング】：core.register_node を Arbitrator ヘルパーへすげ替え！
	mod_mcl_signs.Arbitrator.register_sign_node(node_name_normal, "mod_mcl_signs", node_def_normal)


	-- 2. 壁掛けブラケット型吊り看板 (Hanging Sign Wall) の登録
	local node_name_wall = ":mod_mcl_signs:hanging_sign_wall_" .. name
	local node_def_wall = table.merge(sign_hanging_wall, newfields, {
		tiles = { "mcl_signs_hanging_sign_" .. name .. ".png" },
	}, def)
	mod_mcl_signs.Arbitrator.register_sign_node(node_name_wall, "mod_mcl_signs", node_def_wall)


	-- 3. フェンス・棒固定型吊り看板 (Hanging Sign Attached) の登録
	local node_name_attached = ":mod_mcl_signs:hanging_sign_attached_" .. name
	local node_def_attached = table.merge(sign_hanging_attached, newfields, {
		tiles = { "mcl_signs_hanging_sign_" .. name .. ".png" },
	}, def)
	mod_mcl_signs.Arbitrator.register_sign_node(node_name_attached, "mod_mcl_signs", node_def_attached)
end

-- =================================================================
-- SignEnvと連携した JSON による動的登録システム（高速・決定論的ロード）
-- =================================================================

local is_debug = (json_config.debug == "on" or json_config.debug == true)

-- -----------------------------------------------------------------------------
-- アイテムIDおよびグループの存在検証（高速一元チェック）
-- -----------------------------------------------------------------------------
local function is_valid_ingredient(item_or_group)
	if not item_or_group or type(item_or_group) ~= "string" or item_or_group == "" then
		return true -- 空文字列は有効な空マスとして扱う
	end

	-- 1. グループ指定 ("group:wood" など) の場合
	if item_or_group:sub(1, 6) == "group:" then
		return true
	end

	-- 2. 単体アイテムID の存在チェック
	return core.registered_items[item_or_group] ~= nil
end

-- -----------------------------------------------------------------------------
-- ① 看板ノードの動的登録
-- -----------------------------------------------------------------------------
if json_config.signs and type(json_config.signs) == "table" then
	for _, sign in ipairs(json_config.signs) do
		if sign.name then
			local custom_def = {}
			
			if sign.color then
				mod_mcl_signs.register_sign(sign.name, sign.color, custom_def)
			end
			
			-- 吊り下げ看板（3変種）
			if mod_mcl_signs.register_hanging_sign then
				mod_mcl_signs.register_hanging_sign(sign.name, custom_def)
			end
		end
	end
end

-- -----------------------------------------------------------------------------
-- ② 古いクラフトレシピの消去
-- -----------------------------------------------------------------------------
if json_config.clear_crafts and type(json_config.clear_crafts) == "table" then
	for _, output_item in ipairs(json_config.clear_crafts) do
		if output_item and output_item ~= "" then
			core.clear_craft({ output = output_item })
			if is_debug then
				core.log("action", "[mod_mcl_signs] [CLEARED] Removed recipe for: " .. output_item)
			end
		end
	end
end

-- -----------------------------------------------------------------------------
-- ③ クラフトレシピの動的登録と直接検証
-- -----------------------------------------------------------------------------
if json_config.crafts and type(json_config.crafts) == "table" then
	for _, craft in ipairs(json_config.crafts) do
		if craft.output and craft.recipe then
			local recipe_valid = true

			for row_idx, row in ipairs(craft.recipe) do
				for col_idx, item in ipairs(row) do
					if item ~= "" and not is_valid_ingredient(item) then
						core.log("error", "[mod_mcl_signs] [ERROR] Item NOT FOUND in game: '" .. item .. "' (Row " .. row_idx .. ", Col " .. col_idx .. ")")
						recipe_valid = false
					end
				end
			end

			if recipe_valid then
				core.register_craft({
					output = craft.output,
					recipe = craft.recipe
				})
				if is_debug then
					core.log("action", "[mod_mcl_signs] [SUCCESS] Recipe registered for: " .. craft.output)
				end
			else
				core.log("error", "[mod_mcl_signs] [FAILED] Recipe skipped due to missing item: " .. craft.output)
			end
		end
	end
end

core.register_lbm({
	name = "mod_mcl_signs:arbitrator_restore",
	nodenames = {"group:sign_arbitrated"}, --  register_sign_node で注入したグループ
	label = "Sign Arbitrator Entity Restore Trigger",
	run_at_every_load = true,
	action = function(pos, node)
		--  process_restore メインロジックをキック
		if mod_mcl_signs.Arbitrator and mod_mcl_signs.Arbitrator.process_restore then
			mod_mcl_signs.Arbitrator.process_restore(pos, node)
		end
	end,
})
