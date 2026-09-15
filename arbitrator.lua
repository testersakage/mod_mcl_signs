-- arbitrator.lua

local Arbitrator = {
	registered_engines = {}
}

-- -----------------------------------------------------------------------------
-- 1. エンジン登録API（重複登録ガード付き）
-- -----------------------------------------------------------------------------
function Arbitrator.register_engine(engine_id, def)
	if not engine_id or engine_id == "" then
		core.log("error", "[SignArbitrator] Invalid engine_id provided.")
		return false
	end

	-- 重複登録防止チェック
	if Arbitrator.registered_engines[engine_id] then
		core.log("warning", "[SignArbitrator] Engine '" .. engine_id .. "' is already registered. Skipping.")
		return false
	end

	Arbitrator.registered_engines[engine_id] = {
		on_restore = def.on_restore,   -- LBM発火時の復元処理 (function(pos, node, sign_id))
		entity_name = def.entity_name, -- 自MODが使用する文字Entity名
	}

	core.log("action", "[SignArbitrator] Successfully registered sign engine: " .. engine_id)
	return true
end

-- -----------------------------------------------------------------------------
-- 2. ペアリング識別子 (sign_id) の取得・生成
-- -----------------------------------------------------------------------------
function Arbitrator.get_or_create_sign_id(pos)
	local meta = core.get_meta(pos)
	local sign_id = meta:get_string("sign_id")
	
	if sign_id == "" then
--		sign_id = string.format("%d_%d_%d_%d_%d", pos.x, pos.y, pos.z, os.time(), math.random(1000, 9999))
		sign_id = string.format("%d_%d_%d_%d", pos.x, pos.y, pos.z, core.get_us_time())
		meta:set_string("sign_id", sign_id)
	end
	return sign_id
end

-- -----------------------------------------------------------------------------
-- 3. 識別子 (sign_id) に基づく異物・不一致Entityのクリーンアップ
-- -----------------------------------------------------------------------------
function Arbitrator.clean_unmatched_entities(pos, allow_sign_id, allow_entity_name)
	local pos_str = core.pos_to_string(pos)
	core.log("action", string.format("[SignArbitrator.Trace] === クリーンアップスキャン開始 at %s ===", pos_str))
	core.log("action", string.format("[SignArbitrator.Trace] 許可要件 -> 許可ID: '%s' | 許可Entity名: '%s'", tostring(allow_sign_id), tostring(allow_entity_name)))

	local objs = core.get_objects_inside_radius(pos, 0.6)
	local found_count = 0
	
	for _, obj in pairs(objs) do
		local ent = obj:get_luaentity()
		if ent then
			found_count = found_count + 1
			local ent_id = ent.sign_id or "nil (未所持)"
			core.log("action", string.format("[SignArbitrator.Trace]  -> 検知エンティティ[%d]: '%s' | 脳内ID: '%s'", found_count, ent.name, tostring(ent_id)))
			
			if ent.sign_id then
				if ent.sign_id ~= allow_sign_id then
					core.log("action", string.format("[SignArbitrator.Trace]   ID不一致のためEntityを強制削除: %s (脳内: '%s' vs 許可: '%s')", ent.name, tostring(ent.sign_id), tostring(allow_sign_id)))
					obj:remove()
				else
					core.log("action", "[SignArbitrator.Trace]   ID完全一致！この文字盤を保護します。")
				end
			else
				local is_sign_entity = ent.name:find("sign") or ent.name:find("text")
				if is_sign_entity and ent.name ~= allow_entity_name then
					core.log("action", string.format("[SignArbitrator.Trace]   異物看板Entityのため強制削除: '%s'", ent.name))
					obj:remove()
				elseif is_sign_entity then
					core.log("action", string.format("[SignArbitrator.Trace]   名前は一致（%s）ですが脳内IDが無いため保護判定を保留します", ent.name))
				end
			end
		end
	end
	core.log("action", string.format("[SignArbitrator.Trace] === クリーンアップスキャン終了 (検知総数: %d) ===", found_count))
end

-- -----------------------------------------------------------------------------
-- 4. 復元処理（LBM呼び出し用メインロジック）
-- -----------------------------------------------------------------------------
function Arbitrator.process_restore(pos, node)
	-- 調停対象グループ（sign_arbitrated）でなければ一切介入せずに終了
	if not node or core.get_item_group(node.name, "sign_arbitrated") == 0 then
		return
	end
	local pos_str = core.pos_to_string(pos)
	core.log("action", string.format("[SignArbitrator.Trace] LBM着火！ process_restore 起動 at %s | ノード名: '%s'", pos_str, node.name))

	local meta = core.get_meta(pos)
	local owner_engine = meta:get_string("sign_arbitrator_engine")
	local old_sign_id = meta:get_string("sign_id")
	
	core.log("action", string.format("[SignArbitrator.Trace]  -> メタデータ読込 -> 所属エンジン: '%s' | メタ内既存ID: '%s'", owner_engine, old_sign_id))

	if owner_engine == "" then
		owner_engine = node.name:match("^([^:]+):")
		meta:set_string("sign_arbitrator_engine", owner_engine)
		core.log("action", string.format("[SignArbitrator.Trace]   所属エンジンが空だったため自動補正: '%s'", owner_engine))
	end

	-- ペアリング識別子のロード（無ければ自動生成）
	local sign_id = Arbitrator.get_or_create_sign_id(pos)
	core.log("action", string.format("[SignArbitrator.Trace]  -> 確定した絶対ID: '%s'", sign_id))

	local engine = Arbitrator.registered_engines[owner_engine]
	if engine then
		core.log("action", string.format("[SignArbitrator.Trace]  登録済みエンジン '%s' を発見。クリーンアップ ＆ 復元関数へバトンタッチします", owner_engine))
		
		-- 異物の掃除
		Arbitrator.clean_unmatched_entities(pos, sign_id, engine.entity_name)
		
		-- 各MOD固有の復元（update_signなど）を実行
		if engine.on_restore then
			core.log("action", string.format("[SignArbitrator.Trace]  エンジンの on_restore コールバック関数をキックします..."))
			engine.on_restore(pos, node, sign_id)
		else
			core.log("warning", string.format("[SignArbitrator.Trace]  エンジンはありますが on_restore 関数が未定義です！"))
		end
	else
		core.log("warning", string.format("[SignArbitrator.Trace]  警告: エンジン '%s' が登録されていません！全パージを実行します", owner_engine))
		Arbitrator.clean_unmatched_entities(pos, nil, nil)
	end
end

-- -----------------------------------------------------------------------------
-- 5. 破壊処理（on_destruct 呼び出し用）
-- -----------------------------------------------------------------------------
function Arbitrator.process_destruct(pos)
	local objs = core.get_objects_inside_radius(pos, 0.6)
	for _, obj in pairs(objs) do
		local ent = obj:get_luaentity()
		if ent then
			if ent.sign_id or ent.name:find("sign") or ent.name:find("text") then
				obj:remove()
			end
		end
	end
end

-- -----------------------------------------------------------------------------
-- 6. 看板ノード登録用ヘルパー関数 ★追加箇所
-- -----------------------------------------------------------------------------
function Arbitrator.register_sign_node(node_name, engine_id, node_def)
	local def = table.copy(node_def)

	-- ① 調停対象グループ (sign_arbitrated) を自動追加
	def.groups = def.groups or {}
	def.groups.sign_arbitrated = 1

	-- ② on_construct のラッピング（所有権と sign_id のセット）
	local orig_on_construct = def.on_construct
	def.on_construct = function(pos)
		local meta = core.get_meta(pos)
		meta:set_string("sign_arbitrator_engine", engine_id)
		Arbitrator.get_or_create_sign_id(pos)

		if orig_on_construct then
			orig_on_construct(pos)
		end
	end

	-- ③ on_destruct のラッピング（破棄時の Entity クリーンアップ）
	local orig_on_destruct = def.on_destruct
	def.on_destruct = function(pos)
		Arbitrator.process_destruct(pos)

		if orig_on_destruct then
			orig_on_destruct(pos)
		end
	end

	-- 看板ノードとして登録
	core.register_node(node_name, def)
end

-- =================================================================
-- 7. 【中央集権API】：環境プロファイル・抽象化フック実行エンジン
-- =================================================================
-- =================================================================
-- 7. 【中央集権API】：環境プロファイル・抽象化フック実行エンジン
-- =================================================================
function Arbitrator.apply_system_arbitration(hooks_config)
	-- MODの読み込みが全て完了した後にフック処理を実行（重要！）
	core.register_on_mods_loaded(function()
		local should_hook = core.settings:get_bool("mod_mcl_signs_override_legacy_renderer", true)
		if not should_hook or not hooks_config or not hooks_config.mod_name then return end

		local target_mod = _G[hooks_config.mod_name]
		
		-- A) 描画関数などの動的ラッピング（去勢シールド）
		if target_mod then
			core.log("action", string.format("[SignArbitrator] Profile Loaded. Hooking target mod: '%s'", hooks_config.mod_name))
			for _, func_name in ipairs(hooks_config.functions or {}) do
				if target_mod[func_name] and type(target_mod[func_name]) == "function" then
					local original_func = target_mod[func_name]
					target_mod[func_name] = function(pos, ...)
						if pos then
							local node = core.get_node_or_nil(pos)
							-- 調停グループがあればオリジナル側の描画関数を即座にキャンセル！
							if node and core.get_item_group(node.name, "sign_arbitrated") == 1 then
								return
							end
						end
						return original_func(pos, ...)
					end
				end
			end
		end

		-- B) 他MODの既存LBMの動作をジャック
		if hooks_config.lbm_name and core.registered_lbms then
			for _, lbm_def in ipairs(core.registered_lbms) do
				if lbm_def.name == hooks_config.lbm_name then
					core.log("action", string.format("[SignArbitrator] Intercepted legacy LBM: '%s'", lbm_def.name))
					local original_action = lbm_def.action
					lbm_def.action = function(pos, node, ...)
						-- 調停対象ノードであれば、オリジナルのLBMアクションを完全に阻止して調停エンジンを走らせる
						if node and core.get_item_group(node.name, "sign_arbitrated") == 1 then
							Arbitrator.process_restore(pos, node)
							return
						end
						if original_action then
							return original_action(pos, node, ...)
						end
					end
				end
			end
		end
	end)

	-- C) 【本物の調停LBM登録】：自MODの文字復元用LBM
	core.register_lbm({
		name = "mod_mcl_signs:arbitrator_restore",
		nodenames = {"group:sign_arbitrated"},
		label = "Sign Arbitrator Entity Restore Trigger",
		run_at_every_load = true,
		action = function(pos, node)
			Arbitrator.process_restore(pos, node)
		end,
	})
	
	core.log("action", "[SignArbitrator] Data-driven System Arbitration Hook Registered.")
end

return Arbitrator
