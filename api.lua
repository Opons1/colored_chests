local S = core.get_translator("colored_chests")

colored_chests.chest = {}

function colored_chests.chest.get_chest_formspec(pos)
	local spos = pos.x .. "," .. pos.y .. "," .. pos.z
	local formspec =
		"size[8,9]" ..
		"list[nodemeta:" .. spos .. ";main;0,0.3;8,4;]" ..
		"list[current_player;main;0,4.85;8,1;]" ..
		"list[current_player;main;0,6.08;8,3;8]" ..
		"listring[nodemeta:" .. spos .. ";main]" ..
		"listring[current_player;main]" ..
		default.get_hotbar_bg(0,4.85)
	return formspec
end

function colored_chests.chest.chest_lid_obstructed(pos)
	local above = {x = pos.x, y = pos.y + 1, z = pos.z}
	local def = core.registered_nodes[core.get_node(above).name]
	-- allow ladders, signs, wallmounted things and torches to not obstruct
	if def and
			(def.drawtype == "airlike" or
			def.drawtype == "signlike" or
			def.drawtype == "torchlike" or
			(def.drawtype == "nodebox" and def.paramtype2 == "wallmounted")) then
		return false
	end
	return true
end

function colored_chests.chest.chest_lid_close(pn)
	local chest_open_info = colored_chests.chest.open_chests[pn]
	local pos = chest_open_info.pos
	local sound = chest_open_info.sound
	local swap = chest_open_info.swap

	colored_chests.chest.open_chests[pn] = nil
	for k, v in pairs(colored_chests.chest.open_chests) do
		if v.pos.x == pos.x and v.pos.y == pos.y and v.pos.z == pos.z then
			return true
		end
	end

	local node = core.get_node(pos)
	core.after(0.2, core.swap_node, pos, { name = swap,
			param2 = node.param2 })
	core.sound_play(sound, {gain = 0.3, pos = pos,
		max_hear_distance = 10}, true)
end

colored_chests.chest.open_chests = {}

core.register_on_player_receive_fields(function(player, formname, fields)
	local pn = player:get_player_name()

	if formname ~= "colored_chests:chest" then
		if colored_chests.chest.open_chests[pn] then
			colored_chests.chest.chest_lid_close(pn)
		end

		return
	end

	if not (fields.quit and colored_chests.chest.open_chests[pn]) then
		return
	end

	colored_chests.chest.chest_lid_close(pn)

	return true
end)

core.register_on_leaveplayer(function(player)
	local pn = player:get_player_name()
	if colored_chests.chest.open_chests[pn] then
		colored_chests.chest.chest_lid_close(pn)
	end
end)

function colored_chests.chest.register_chest(prefixed_name, d)
	local name = prefixed_name:sub(1,1) == ':' and prefixed_name:sub(2,-1) or prefixed_name
	local def = table.copy(d)
	def.drawtype = "mesh"
	def.visual = "mesh"
	def.paramtype = "light"
	def.paramtype2 = "facedir"
	def.legacy_facedir_simple = true
	def.is_ground_content = false

	if def.protected then
		def.description = S("Locked").." "..def.description
		def.on_construct = function(pos)
			local meta = core.get_meta(pos)
			meta:set_string("infotext", S("Locked Colored Chest"))
			meta:set_string("owner", "")
			local inv = meta:get_inventory()
			inv:set_size("main", 8*4)
		end
		def.after_place_node = function(pos, placer)
			local meta = core.get_meta(pos)
			meta:set_string("owner", placer:get_player_name() or "")
			meta:set_string("infotext", S("Locked Colored Chest (owned by @1)", meta:get_string("owner")))
		end
		def.can_dig = function(pos,player)
			local meta = core.get_meta(pos);
			local inv = meta:get_inventory()
			return inv:is_empty("main") and
					default.can_interact_with_node(player, pos)
		end
		def.allow_metadata_inventory_move = function(pos, from_list, from_index,
				to_list, to_index, count, player)
			if not default.can_interact_with_node(player, pos) then
				return 0
			end
			return count
		end
		def.allow_metadata_inventory_put = function(pos, listname, index, stack, player)
			if not default.can_interact_with_node(player, pos) then
				return 0
			end
			return stack:get_count()
		end
		def.allow_metadata_inventory_take = function(pos, listname, index, stack, player)
			if not default.can_interact_with_node(player, pos) then
				return 0
			end
			return stack:get_count()
		end
		def.on_rightclick = function(pos, node, clicker, itemstack, pointed_thing)
			if not default.can_interact_with_node(clicker, pos) then
				return itemstack
			end

			local cn = clicker:get_player_name()

			if colored_chests.chest.open_chests[cn] then
				colored_chests.chest.chest_lid_close(cn)
			end

			core.sound_play(def.sound_open, {gain = 0.3,
					pos = pos, max_hear_distance = 10}, true)
			if not colored_chests.chest.chest_lid_obstructed(pos) then
				core.swap_node(pos,
						{ name = name .. "_open",
						param2 = node.param2 })
			end
			core.after(0.2, core.show_formspec, cn,
					"colored_chests:chest", colored_chests.chest.get_chest_formspec(pos))
			colored_chests.chest.open_chests[cn] = { pos = pos,
					sound = def.sound_close, swap = name }
		end
		def.on_blast = function() end
		def.on_key_use = function(pos, player)
			local secret = core.get_meta(pos):get_string("key_lock_secret")
			local itemstack = player:get_wielded_item()
			local key_meta = itemstack:get_meta()

			if itemstack:get_metadata() == "" then
				return
			end

			if key_meta:get_string("secret") == "" then
				key_meta:set_string("secret", core.parse_json(itemstack:get_metadata()).secret)
				itemstack:set_metadata("")
			end

			if secret ~= key_meta:get_string("secret") then
				return
			end

			core.show_formspec(
				player:get_player_name(),
				"colored_chests:chest_locked",
				colored_chests.chest.get_chest_formspec(pos)
			)
		end
		def.on_skeleton_key_use = function(pos, player, newsecret)
			local meta = core.get_meta(pos)
			local owner = meta:get_string("owner")
			local pn = player:get_player_name()

			-- verify placer is owner of lockable chest
			if owner ~= pn then
				core.record_protection_violation(pos, pn)
				core.chat_send_player(pn, S("You do not own this chest."))
				return nil
			end

			local secret = meta:get_string("key_lock_secret")
			if secret == "" then
				secret = newsecret
				meta:set_string("key_lock_secret", secret)
			end

			return secret, S("a locked chest"), owner
		end
	else
		def.on_construct = function(pos)
			local meta = core.get_meta(pos)
			meta:set_string("infotext", S("Colored Chest"))
			local inv = meta:get_inventory()
			inv:set_size("main", 8*4)
		end
		def.can_dig = function(pos,player)
			local meta = core.get_meta(pos);
			local inv = meta:get_inventory()
			return inv:is_empty("main")
		end
		def.on_rightclick = function(pos, node, clicker)
			local cn = clicker:get_player_name()

			if colored_chests.chest.open_chests[cn] then
				colored_chests.chest.chest_lid_close(cn)
			end

			core.sound_play(def.sound_open, {gain = 0.3, pos = pos,
					max_hear_distance = 10}, true)
			if not colored_chests.chest.chest_lid_obstructed(pos) then
				core.swap_node(pos, {
						name = name .. "_open",
						param2 = node.param2 })
			end
			core.after(0.2, core.show_formspec,
					cn,
					"colored_chests:chest", colored_chests.chest.get_chest_formspec(pos))
			colored_chests.chest.open_chests[cn] = { pos = pos,
					sound = def.sound_close, swap = name }
		end
		def.on_blast = function(pos)
			local drops = {}
			colored_chests.get_inventory_drops(pos, "main", drops)
			drops[#drops+1] = name
			core.remove_node(pos)
			return drops
		end
	end

	default.set_inventory_action_loggers(def, "chest")

	local def_opened = table.copy(def)
	local def_closed = table.copy(def)

	def_opened.mesh = "chest_open.obj"
	for i = 1, #def_opened.tiles do
		if type(def_opened.tiles[i]) == "string" then
			def_opened.tiles[i] = {name = def_opened.tiles[i], backface_culling = true}
		elseif def_opened.tiles[i].backface_culling == nil then
			def_opened.tiles[i].backface_culling = true
		end
	end
	def_opened.drop = name
	def_opened.groups.not_in_creative_inventory = 1
	def_opened.selection_box = {
		type = "fixed",
		fixed = { -1/2, -1/2, -1/2, 1/2, 3/16, 1/2 },
	}
	def_opened.can_dig = function()
		return false
	end
	def_opened.on_blast = function() end

	def_closed.mesh = nil
	def_closed.drawtype = nil
	def_closed.tiles[6] = def.tiles[5] -- swap textures around for "normal"
	def_closed.tiles[5] = def.tiles[3] -- drawtype to make them match the mesh
	def_closed.tiles[3] = def.tiles[3].."^[transformFX"

	core.register_node(prefixed_name, def_closed)
	core.register_node(prefixed_name .. "_open", def_opened)

	if core.get_modpath("wrench") then
		local wrenchdata = {
			lists = {"main"},
			metas = {
				infotext = wrench.META_TYPE_STRING,
				formspec = wrench.META_TYPE_STRING,
			},
		}
		if def.protected then 
			wrenchdata.metas.owner = wrench.META_TYPE_STRING
			wrenchdata.metas.key_lock_secret = wrench.META_TYPE_STRING
			wrenchdata.owned = true
		end
		wrench.register_node(prefixed_name, wrenchdata)
	end

	-- convert old chests to this new variant
	if name == "colored_chests:chest" or name == "colored_chests:chest_locked" then
		core.register_lbm({
			label = "update chests to opening chests",
			name = "colored_chests:upgrade_" .. name:sub(9,-1) .. "_v2",
			nodenames = {name},
			action = function(pos, node)
				local meta = core.get_meta(pos)
				meta:set_string("formspec", nil)
				local inv = meta:get_inventory()
				local list = inv:get_list("colored_chests:chest")
				if list then
					inv:set_size("main", 8*4)
					inv:set_list("main", list)
					inv:set_list("colored_chests:chest", nil)
				end
			end
		})
	end

	-- close opened chests on load
	core.register_lbm({
		label = "close opened chests on load",
		name = "colored_chests:close_" .. prefixed_name:gsub(":", "_") .. "_open",
		nodenames = {prefixed_name .. "_open"},
		run_at_every_load = true,
		action = function(pos, node)
			node.name = prefixed_name
			core.swap_node(pos, node)
		end
	})
end
