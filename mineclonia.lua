-- Entire file heavily adapted from mineclonia mcl_chests/init.lua, GPL 3.0
mcl_colored_chests = {}
local mod_mcl_decor = core.get_modpath("mcl_decor") ~= nil
local is_voxelibre = core.get_game_info().id == "mineclone2"

local moddye = "mcl_dyes:"
if is_voxelibre then
	local mcl_dyes = dofile(core.get_modpath(core.get_current_modname()).."/voxelibre_colors.lua")
	moddye = "mcl_dye:"
end

local S = core.get_translator(core.get_current_modname())
local F = core.formspec_escape
local C = core.colorize

local sf = string.format

local mod_doc = core.get_modpath("doc")

local tiles_chest_normal_small = { "mcl_chests_normal.png" }
local tiles_chest_normal_double = { "mcl_chests_normal_double.png" }

local function co(intable, colorstring)
	local newtable = {}
	for i, strin in ipairs(intable) do
		-- FUTUREIMPROVEMENT: black is too dark, and all colors seem a little off. Keep experimenting with this.
		table.insert(newtable, intable[i] .. "^[contrast:0:40^[multiply:" .. colorstring)
	end
	return newtable
end

function mcl_colored_chests.update_comparators(pos)
	if is_voxelibre then
		-- Not implemented apparently
	else
		-- mineclonia
		mcl_redstone.update_comparators(pos)
	end
end

-- Chest Entity
local animate_chests = (core.settings:get_bool("animated_chests") ~= false)
local entity_animations = {
	chest = {
		speed = 25,
		open = { x = 0, y = 7 },
		close = { x = 13, y = 20 },
	},
}

core.register_entity("colored_chests:chest", {
	initial_properties = {
		visual = "mesh",
		pointable = false,
		physical = false,
		static_save = false,
	},

	set_animation = function(self, animname)
		local anim_table = entity_animations[self.animation_type]
		local anim = anim_table[animname]
		if not anim then return end
		self.object:set_animation(anim, anim_table.speed, 0, false)
	end,

	open = function(self, playername)
		self.players[playername] = true
		if not self.is_open then
			self:set_animation("open")
			core.sound_play(self.sound_prefix .. "_open", { pos = self.node_pos, gain = 0.5, max_hear_distance = 16 },
				true)
			self.is_open = true
		end
	end,

	close = function(self, playername)
		local playerlist = self.players
		playerlist[playername] = nil
		if self.is_open then
			if next(playerlist) then
				return
			end
			self:set_animation("close")
			core.sound_play(self.sound_prefix .. "_close",
				{ pos = self.node_pos, gain = 0.3, max_hear_distance = 16 },
				true)
			self.is_open = false
		end
	end,

	initialize = function(self, node_pos, node_name, textures, dir, double, sound_prefix, mesh_prefix, animation_type, node_param2)
		self.node_pos = node_pos
		self.node_name = node_name
		self.node_param2 = node_param2
		self.sound_prefix = sound_prefix
		self.animation_type = animation_type
		local obj = self.object
		obj:set_armor_groups({ immortal = 1 })
		obj:set_properties({
			textures = textures,
			mesh = mesh_prefix .. (double and "_double" or "") .. ".b3d",
		})
		self:set_yaw(dir)
		self.players = {}
	end,

	reinitialize = function(self, node_name)
		self.node_name = node_name
	end,

	set_yaw = function(self, dir)
		self.object:set_yaw(core.dir_to_yaw(dir))
	end,

	check = function(self)
		local node_pos, node_name = self.node_pos, self.node_name
		if not node_pos or not node_name then
			return false
		end
		local node = core.get_node(node_pos)
		if node.name ~= node_name then
			return false
		end
		return true
	end,

	on_activate = function(self, initialization_data)
		if initialization_data and initialization_data:find("\"###colored_chests:chest###\"") then
			self:initialize(unpack(core.deserialize(initialization_data)))
		else
			core.log("warning", "[mcl_colored_chests] on_activate called without proper initialization_data ... removing entity")
			self.object:remove()
		end
	end,

	on_step = function(self)
		if not self:check() then
			self.object:remove()
		end
	end,
	_mcl_pistons_unmovable = true
})

local function get_entity_pos(pos, dir, double)
	pos = vector.copy(pos)
	if double then
		local add, mul, vec, cross = vector.add, vector.multiply, vector.new, vector.cross
		pos = add(pos, mul(cross(dir, vec(0, 1, 0)), -0.5))
	end
	return pos
end

local function find_entity(pos)
	for obj in core.objects_inside_radius(pos, 0) do
		local luaentity = obj:get_luaentity()
		if luaentity and luaentity.name == "colored_chests:chest" then
			return luaentity
		end
	end
end

local function get_entity_info(pos, param2, double, dir, _)
	dir = dir or core.facedir_to_dir(param2)
	return dir, get_entity_pos(pos, dir, double)
end

local function create_entity(pos, node_name, textures, param2, double, sound_prefix, mesh_prefix, animation_type, dir, entity_pos)
	if animate_chests or double then
		dir, entity_pos = get_entity_info(pos, param2, double, dir, entity_pos)
		local initialization_data = core.serialize({pos, node_name, textures, dir, double, sound_prefix, mesh_prefix, animation_type, param2, "###colored_chests:chest###"})
		local obj = core.add_entity(entity_pos, "colored_chests:chest", initialization_data)
		if obj and obj:get_pos() then
			local luaentity = obj:get_luaentity()
			return luaentity
		else
			core.log("warning", "[mcl_colored_chests] Failed to create entity at " .. (entity_pos and core.pos_to_string(entity_pos, 1) or "nil"))
		end
	end
end

local function find_or_create_entity(pos, node_name, textures, param2, double, sound_prefix, mesh_prefix, animation_type
	, dir, entity_pos)
	dir, entity_pos = get_entity_info(pos, param2, double, dir, entity_pos)
	return find_entity(entity_pos) or
		create_entity(pos, node_name, textures, param2, double, sound_prefix, mesh_prefix, animation_type, dir, entity_pos)
end

local no_rotate, simple_rotate
if core.get_modpath("screwdriver") then
	no_rotate = screwdriver.disallow
	simple_rotate = function(pos, node, user, mode, new_param2)
		if screwdriver.rotate_simple(pos, node, user, mode, new_param2) ~= false then
			local nodename = node.name
			local nodedef = core.registered_nodes[nodename]
			local dir = core.facedir_to_dir(new_param2)
			if animate_chests then
				find_or_create_entity(pos, nodename, nodedef._chest_entity_textures, new_param2, false, nodedef._chest_entity_sound, nodedef._chest_entity_mesh, nodedef._chest_entity_animation_type, dir):set_yaw(dir)
			end
		else
			return false
		end
	end
end

--[[ List of open chests.
Key: Player name
Value:
	If player is using a chest: { pos = <chest node position> }
	Otherwise: nil ]]
local open_chests = {}

local function back_is_blocked(pos, dir)
	pos = vector.add(pos, dir)
	local def = core.registered_nodes[core.get_node(pos).name]
	pos.y = pos.y + 1
	local def2 = core.registered_nodes[core.get_node(pos).name]
	return not def or def.groups.opaque == 1 or not def2 or def2.groups.opaque == 1
end

-- To be called if a player opened a chest
local function player_chest_open(player, pos, node_name, textures, param2, double, sound, mesh)
	local name = player:get_player_name()
	open_chests[name] = {
		pos = pos,
		node_name = node_name,
		textures = textures,
		param2 = param2,
		double = double,
		sound = sound,
		mesh = mesh
	}
	if animate_chests then
		local dir = core.facedir_to_dir(param2)
		local blocked = (back_is_blocked(pos, dir) or double and back_is_blocked(mcl_util.get_double_container_neighbor_pos(pos, param2, node_name:sub(-4)), dir))
		find_or_create_entity(pos, node_name, textures, param2, double, sound, mesh, "chest", dir):open(name, blocked)
	else
		core.sound_play(sound .. "_open", { pos = pos, gain = 0.5, max_hear_distance = 16 }, true)
	end
	if not is_voxelibre then
		mobs_mc.enrage_piglins (player, true)
	end
end

-- Simple protection checking functions
local function protection_check_move(pos, _, _, _, _, count, player)
	local name = player:get_player_name()
	if core.is_protected(pos, name) then
		core.record_protection_violation(pos, name)
		return 0
	else
		return count
	end
end

local function protection_check_put_take(pos, _, _, stack, player)
	local name = player:get_player_name()
	if core.is_protected(pos, name) then
		core.record_protection_violation(pos, name)
		return 0
	else
		return stack:get_count()
	end
end

-- To be called when a chest is closed (not relevant but included for ease of use in the future)
local function chest_update_after_close(pos)
	local node = core.get_node(pos)
	if animate_chests then
	end
end

-- To be called if a player closed a chest
local function player_chest_close(player)
	local name = player:get_player_name()
	local open_chest = open_chests[name]
	if open_chest == nil then
		return
	end
	if animate_chests then
		find_or_create_entity(open_chest.pos, open_chest.node_name, open_chest.textures, open_chest.param2, open_chest.double, open_chest.sound, open_chest.mesh, "chest"):close(name)
	else
		core.sound_play(open_chest.sound .. "_close", { pos = open_chest.pos, gain = 0.5, max_hear_distance = 16 }, true)
	end
	chest_update_after_close(open_chest.pos)

	open_chests[name] = nil
end

function mcl_colored_chests.on_punch(pos, node, puncher, pointed_thing)
	if not puncher or not puncher:is_player() then
		return
	end
	local player = puncher:get_player_name()
	local itemstack = puncher:get_wielded_item()
	local item_name = itemstack:get_name() or ""
	if not item_name then
		return
	end
	-- determine if small or left or right
	local _type = string.split(node.name,"_")
	local _color = "none"
	if _type ~= nil then
		_color = _type[#_type-1]
		_type = _type[#_type]
	end
	local needed_dye = {
		small = 8,
		left = 16,
		right = 16
	}
	for k,v in pairs(mcl_dyes.colors) do
		local node_prefix = "colored_chests:chest_" .. k
		if item_name == moddye .. k and (not string.find(node.name, node_prefix)) then
			-- if count is >= 8, then decrement by 8 and set stack. also change box to the other kind.
			if (core.is_creative_enabled(player)) or itemstack:get_count() >= needed_dye[_type] then
				local small_name = node_prefix .. "_small"
				local left_name = node_prefix .. "_left"
				local right_name = node_prefix .. "_right"
				local n = core.get_node(pos)
				local param2 = n.param2
				local meta = core.get_meta(pos)
				if _type == "small" then
					core.swap_node(pos, { name = small_name, param2=param2})
					-- this nested after-after opens the chest and closes it, to immediately show the new color.
					core.after(0, function()
						player_chest_open(puncher, pos, small_name, co(tiles_chest_normal_small,v.rgb), node.param2, false, "default_chest",
							"mcl_chests_chest")
						core.after(0, function()
							player_chest_close(puncher)
						end)
					end)
				elseif _type == "right" then
					core.swap_node(pos, { name = right_name, param2 = param2 })
					local p = mcl_util.get_double_container_neighbor_pos(pos, param2, "right")
					core.swap_node(p, { name = left_name, param2 = param2 })
					create_entity(p, left_name, co(tiles_chest_normal_double,v.rgb), param2, true,
						"default_chest",
						"mcl_chests_chest", "chest")
					-- somehow, the right side does not need to be redrawn immediately, probably because
					-- the entity is stored on the left node?
				elseif _type == "left" then
					core.swap_node(pos, { name = left_name, param2 = param2 })
					local p = mcl_util.get_double_container_neighbor_pos(pos, param2, "left")
					core.swap_node(p, { name = right_name, param2 = param2 })
					create_entity(pos, right_name, co(tiles_chest_normal_double,v.rgb), param2, true,
						"default_chest",
						"mcl_chests_chest", "chest")
					core.after(0, function()
						player_chest_open(puncher, pos, left_name, co(tiles_chest_normal_double,v.rgb), node.param2, true, "default_chest",
							"mcl_chests_chest")
						core.after(0, function()
							player_chest_close(puncher)
						end)
					end)
				end
				-- take the dye from the player if not in creative
				if not core.is_creative_enabled(player) then
					itemstack:set_count(itemstack:get_count()-needed_dye[_type])
					puncher:set_wielded_item(itemstack)
				end
				core.log("action", player .. "dyed a colored chest " .. k .. ".")
			else
				core.chat_send_player(player,"Not enough dye: need " .. needed_dye[_type] .. "!")
			end
			break -- short-circuit
		end
	end
end

-- This is a helper function to register chests. Some parameters were for trapped chests which are not a part of mcl_colored_chests
local function register_chest(basename, desc, longdesc, usagehelp, tt_help, tiles_table, hidden, redstone,
							  on_rightclick_addendum, on_rightclick_addendum_left, on_rightclick_addendum_right, drop,
							  canonical_basename, colorname, readablename)
	-- START OF register_chest FUNCTION BODY
	if not drop then
		drop = "colored_chests:" .. basename .. "_" .. colorname
	else
		drop = "colored_chests:" .. drop
	end
	-- The basename of the "canonical" version of the node, if set (e.g.: trapped_chest_on → trapped_chest).
	-- Used to get a shared formspec ID and to swap the node back to the canonical version in on_construct.
	if not canonical_basename then
		canonical_basename = basename
	end

	local function double_chest_add_item(top_inv, bottom_inv, listname, stack)
		if not stack or stack:is_empty() then
			return
		end

		local name = stack:get_name()

		local function top_off(inv, stack)
			for c, chest_stack in ipairs(inv:get_list(listname)) do
				if stack:is_empty() then
					break
				end

				if chest_stack:get_name() == name and chest_stack:get_free_space() > 0 then
					stack = chest_stack:add_item(stack)
					inv:set_stack(listname, c, chest_stack)
				end
			end

			return stack
		end

		stack = top_off(top_inv, stack)
		stack = top_off(bottom_inv, stack)

		if not stack:is_empty() then
			stack = top_inv:add_item(listname, stack)
			if not stack:is_empty() then
				bottom_inv:add_item(listname, stack)
			end
		end
	end

	local drop_items_chest = mcl_util.drop_items_from_meta_container("main")

	local function on_chest_blast(pos)
		local node = core.get_node(pos)
		drop_items_chest(pos, node)
		core.remove_node(pos)
	end

	local function limit_put_list(stack, list)
		for _, other in ipairs(list) do
			stack = other:add_item(stack)
			if stack:is_empty() then
				break
			end
		end
		return stack
	end

	local function limit_put(stack, inv1, inv2)
		local leftover = ItemStack(stack)
		leftover = limit_put_list(leftover, inv1:get_list("main"))
		leftover = limit_put_list(leftover, inv2:get_list("main"))
		return stack:get_count() - leftover:get_count()
	end

	local small_name = "colored_chests:" .. basename .. "_" .. colorname .. "_small"
	local small_textures = tiles_table.small
	local left_name =  "colored_chests:" .. basename .. "_" .. colorname .. "_left"
	local left_textures = tiles_table.double

	core.register_node("colored_chests:" .. basename .. "_" .. colorname , {
		description = desc,
		_tt_help = tt_help,
		_doc_items_longdesc = longdesc,
		_doc_items_usagehelp = usagehelp,
		_doc_items_hidden = hidden,
		drawtype = "mesh",
		mesh = "mcl_chests_chest.b3d",
		tiles = small_textures,
		is_ground_content = false,
		paramtype = "light",
		paramtype2 = "facedir",
		sounds = mcl_sounds.node_sound_wood_defaults(),
		on_punch = mcl_colored_chests.on_punch,
		groups = { deco_block = 1, chest = 1 },
		on_construct = function(pos, _)
			local node = core.get_node(pos)
			node.name = small_name
			core.set_node(pos, node)
		end,
		after_place_node = function(pos, _, itemstack, _)
			core.get_meta(pos):set_string("name", itemstack:get_meta():get_string("name"))
		end,
		_mcl_burntime = 15
	})

	local function close_forms(canonical_basename, pos)
		for pl in mcl_util.connected_players(pos, 30) do
			core.close_formspec(pl:get_player_name(), "colored_chests:" .. canonical_basename .. "_" .. colorname .. "_" .. pos.x .. "_" .. pos.y .. "_" .. pos.z)
		end
	end

	core.register_node(small_name, {
		description = desc,
		_tt_help = tt_help,
		_doc_items_longdesc = longdesc,
		_doc_items_usagehelp = usagehelp,
		_doc_items_hidden = hidden,
		drawtype = animate_chests and "nodebox" or "mesh",
		mesh = not animate_chests and "mcl_chests_chest.obj" or nil,
		node_box = animate_chests and {
			type = "fixed",
			fixed = {-0.4375, -0.5, -0.4375, 0.4375, 0.375, 0.4375},
		} or nil,
		collision_box = {
			type = "fixed",
			fixed = {-0.4375, -0.5, -0.4375, 0.4375, 0.375, 0.4375},
		},
		selection_box = {
			type = "fixed",
			fixed = {-0.4375, -0.5, -0.4375, 0.4375, 0.375, 0.4375},
		},
		tiles = animate_chests and {"blank.png^[resize:16x16"} or small_textures,
		use_texture_alpha = "blend",
		_chest_entity_textures = small_textures,
		_chest_entity_sound = "default_chest",
		_chest_entity_mesh = "mcl_chests_chest",
		_chest_entity_animation_type = "chest",
		paramtype = "light",
		paramtype2 = "facedir",
		drop = drop,
		_mcl_baseitem = "colored_chests:"..basename .. "_" .. colorname ,
		groups = {
			handy = 1,
			axey = 1,
			container = 2,
			deco_block = 1,
			material_wood = 1,
			flammable = -1,
			chest_entity = 1,
			not_in_creative_inventory = 1,
			pathfinder_partial = 2,
			piglin_protected = 1,
		},
		is_ground_content = false,
		sounds = mcl_sounds.node_sound_wood_defaults(),
		on_punch = mcl_colored_chests.on_punch,
		on_construct = function(pos)
			local param2 = core.get_node(pos).param2
			local meta = core.get_meta(pos)
			local inv = meta:get_inventory()
			inv:set_size("main", 9 * 3)
			--[[ The "input" list is *another* workaround (hahahaha!) around the fact that Minetest
			does not support listrings to put items into an alternative list if the first one
			happens to be full. See <https://github.com/minetest/minetest/issues/5343>.
			This list is a hidden input-only list and immediately puts items into the appropriate chest.
			It is only used for listrings and hoppers. This workaround is not that bad because it only
			requires a simple “inventory allows” check for large chests.]]
			-- FIXME: Refactor the listrings as soon Minetest supports alternative listrings
			-- BEGIN OF LISTRING WORKAROUND
			inv:set_size("input", 1)
			-- END OF LISTRING WORKAROUND
			if core.get_node(mcl_util.get_double_container_neighbor_pos(pos, param2, "right")).name ==
				"colored_chests:" .. canonical_basename .. "_" .. colorname .. "_small" then
				core.swap_node(pos, { name = "colored_chests:" .. canonical_basename .. "_" .. colorname .. "_right", param2 = param2 })
				local p = mcl_util.get_double_container_neighbor_pos(pos, param2, "right")
				core.swap_node(p, { name = "colored_chests:" .. canonical_basename .. "_" .. colorname .. "_left", param2 = param2 })
				create_entity(p, "colored_chests:" .. canonical_basename .. "_" .. colorname .. "_left", left_textures, param2, true,
					"default_chest",
					"mcl_chests_chest", "chest")
			elseif core.get_node(mcl_util.get_double_container_neighbor_pos(pos, param2, "left")).name ==
				"colored_chests:" .. canonical_basename .. "_" .. colorname .. "_small" then
				core.swap_node(pos, { name = "colored_chests:" .. canonical_basename .. "_" .. colorname .. "_left", param2 = param2 })
				create_entity(pos, "colored_chests:" .. canonical_basename .. "_" .. colorname .. "_left", left_textures, param2, true,
					"default_chest",
					"mcl_chests_chest", "chest")
				local p = mcl_util.get_double_container_neighbor_pos(pos, param2, "left")
				core.swap_node(p, { name = "colored_chests:" .. canonical_basename .. "_" .. colorname .. "_right", param2 = param2 })
			else
				core.swap_node(pos, { name = "colored_chests:" .. canonical_basename .. "_" .. colorname .. "_small", param2 = param2 })
				create_entity(pos, small_name, small_textures, param2, false, "default_chest", "mcl_chests_chest",
					"chest")
			end
		end,
		after_place_node = function(pos, _, itemstack,  _)
			core.get_meta(pos):set_string("name", itemstack:get_meta():get_string("name"))
		end,
		after_dig_node = drop_items_chest,
		on_blast = on_chest_blast,
		allow_metadata_inventory_move = protection_check_move,
		allow_metadata_inventory_take = protection_check_put_take,
		allow_metadata_inventory_put = protection_check_put_take,
		on_metadata_inventory_move = function(pos, _, _, _, _, _, player)
			core.log("action", player:get_player_name() ..
				" moves stuff in chest at " .. core.pos_to_string(pos))
		end,
		on_metadata_inventory_put = function(pos, listname, _, stack, player)
			core.log("action", player:get_player_name() ..
				" moves stuff to chest at " .. core.pos_to_string(pos))
			-- BEGIN OF LISTRING WORKAROUND
			if listname == "input" then
				local inv = core.get_inventory({ type = "node", pos = pos })
				inv:add_item("main", stack)
			end
			-- END OF LISTRING WORKAROUND
			mcl_colored_chests.update_comparators(pos)
		end,
		on_metadata_inventory_take = function(pos, _, _, _, player)
			core.log("action", player:get_player_name() ..
				" takes stuff from chest at " .. core.pos_to_string(pos))
			mcl_colored_chests.update_comparators(pos)
		end,
		_mcl_hardness = 2.5,

		on_rightclick = function(pos, node, clicker) --, itemstack)
			local def = core.registered_nodes[core.get_node({ x = pos.x, y = pos.y + 1, z = pos.z }).name]
			if not def or def.groups.opaque == 1 then
				-- won't open if there is no space from the top
				return false
			end
			local name = core.get_meta(pos):get_string("name")
			if name == "" then
				name = readablename .. " " .. S("Colored Chest")
			end

			core.show_formspec(clicker:get_player_name(),
				sf("colored_chests:%s_%s_%s_%s", canonical_basename .. "_" .. colorname , pos.x, pos.y, pos.z),
				table.concat({
					"formspec_version[4]",
					"size[11.75,10.425]",

					"label[0.375,0.375;" .. F(C(mcl_formspec.label_color, name)) .. "]",
					mcl_formspec.get_itemslot_bg_v4(0.375, 0.75, 9, 3),
					sf("list[nodemeta:%s,%s,%s;main;0.375,0.75;9,3;]", pos.x, pos.y, pos.z),
					"label[0.375,4.7;" .. F(C(mcl_formspec.label_color, S("Inventory"))) .. "]",
					mcl_formspec.get_itemslot_bg_v4(0.375, 5.1, 9, 3),
					"list[current_player;main;0.375,5.1;9,3;9]",

					mcl_formspec.get_itemslot_bg_v4(0.375, 9.05, 9, 1),
					"list[current_player;main;0.375,9.05;9,1;]",
					sf("listring[nodemeta:%s,%s,%s;main]", pos.x, pos.y, pos.z),
					"listring[current_player;main]",
				})
			)

			if on_rightclick_addendum then
				on_rightclick_addendum(pos, node, clicker)
			end

			player_chest_open(clicker, pos, small_name, small_textures, node.param2, false, "default_chest",
				"mcl_chests_chest")
		end,

		on_destruct = function(pos)
			close_forms(canonical_basename, pos)
		end,
		_mcl_redstone = redstone,
		on_rotate = simple_rotate,
	})

	core.register_node(left_name, {
		drawtype = "nodebox",
		node_box = {
			type = "fixed",
			fixed = { -0.4375, -0.5, -0.4375, 0.5, 0.375, 0.4375 },
		},
		tiles = { "blank.png^[resize:16x16" },
		use_texture_alpha = "blend",
		_chest_entity_textures = left_textures,
		_chest_entity_sound = "default_chest",
		_chest_entity_mesh = "mcl_chests_chest",
		_chest_entity_animation_type = "chest",
		paramtype = "light",
		paramtype2 = "facedir",
		_mcl_baseitem = "colored_chests:"..basename .. "_" .. colorname ,
		groups = {
			handy = 1,
			axey = 1,
			container = 5,
			not_in_creative_inventory = 1,
			material_wood = 1,
			flammable = -1,
			chest_entity = 1,
			double_chest = 1,
			pathfinder_partial = 2,
			piglin_protected = 1,
		},
		drop = drop,
		is_ground_content = false,
		sounds = mcl_sounds.node_sound_wood_defaults(),
		on_punch = mcl_colored_chests.on_punch,
		on_construct = function(pos)
			local n = core.get_node(pos)
			local param2 = n.param2
			local p = mcl_util.get_double_container_neighbor_pos(pos, param2, "left")
			if not p or core.get_node(p).name ~= "colored_chests:" .. canonical_basename .. "_" .. colorname .. "_right" then
				n.name = "colored_chests:" .. canonical_basename .. "_" .. colorname .. "_small"
				core.swap_node(pos, n)
			end
			create_entity(pos, left_name, left_textures, param2, true, "default_chest", "mcl_chests_chest", "chest")
		end,
		after_place_node = function(pos, _, itemstack, _)
			core.get_meta(pos):set_string("name", itemstack:get_meta():get_string("name"))
		end,
		on_destruct = function(pos)
			local n = core.get_node(pos)
			if n.name == small_name then
				return
			end

			close_forms(canonical_basename, pos)

			local param2 = n.param2
			local p = mcl_util.get_double_container_neighbor_pos(pos, param2, "left")
			if not p or core.get_node(p).name ~= "colored_chests:" .. basename .. "_" .. colorname .. "_right" then
				return
			end
			close_forms(canonical_basename, p)

			core.swap_node(p, { name = small_name, param2 = param2 })
			create_entity(p, small_name, small_textures, param2, false, "default_chest", "mcl_chests_chest", "chest")
		end,
		after_dig_node = drop_items_chest,
		on_blast = on_chest_blast,
		allow_metadata_inventory_move = protection_check_move,
		allow_metadata_inventory_take = protection_check_put_take,
		allow_metadata_inventory_put = function(pos, listname, _, stack, player)
			local other_pos = mcl_util.get_double_container_neighbor_pos(pos, core.get_node(pos).param2, "left")
			if core.get_item_group(core.get_node(other_pos).name, "double_chest") == 0 then
				return 0
			end
			local name = player:get_player_name()
			if core.is_protected(pos, name) then
				core.record_protection_violation(pos, name)
				return 0
				-- BEGIN OF LISTRING WORKAROUND
			elseif listname == "input" then
				local inv = core.get_inventory({ type = "node", pos = pos })
				local other_inv = core.get_inventory({ type = "node", pos = other_pos })
				return limit_put(stack, inv, other_inv)
				-- END OF LISTRING WORKAROUND
			else
				return stack:get_count()
			end
		end,
		on_metadata_inventory_move = function(pos, _, _, _, _, _, player)
			core.log("action", player:get_player_name() ..
				" moves stuff in chest at " .. core.pos_to_string(pos))
		end,
		on_metadata_inventory_put = function(pos, listname, _, stack, player)
			core.log("action", player:get_player_name() ..
				" moves stuff to chest at " .. core.pos_to_string(pos))
			local other_pos = mcl_util.get_double_container_neighbor_pos(pos, core.get_node(pos).param2, "left")
			-- BEGIN OF LISTRING WORKAROUND
			if listname == "input" then
				local inv = core.get_inventory({ type = "node", pos = pos })
				local other_inv = core.get_inventory({ type = "node", pos = other_pos })

				inv:set_stack("input", 1, nil)

				double_chest_add_item(inv, other_inv, "main", stack)
			end
			-- END OF LISTRING WORKAROUND
			mcl_colored_chests.update_comparators(pos)
			mcl_colored_chests.update_comparators(other_pos)
		end,
		on_metadata_inventory_take = function(pos, _, _, _, player)
			core.log("action", player:get_player_name() ..
				" takes stuff from chest at " .. core.pos_to_string(pos))
			local other_pos = mcl_util.get_double_container_neighbor_pos(pos, core.get_node(pos).param2, "left")
			mcl_colored_chests.update_comparators(pos)
			mcl_colored_chests.update_comparators(other_pos)
		end,
		_mcl_hardness = 2.5,

		on_rightclick = function(pos, node, clicker)
			local pos_other = mcl_util.get_double_container_neighbor_pos(pos, node.param2, "left")
			local above_def = core.registered_nodes[core.get_node({ x = pos.x, y = pos.y + 1, z = pos.z }).name]
			local above_def_other = core.registered_nodes[
			core.get_node({ x = pos_other.x, y = pos_other.y + 1, z = pos_other.z }).name]

			if not above_def or above_def.groups.opaque == 1 or not above_def_other or above_def_other.groups.opaque == 1 then
				-- won't open if there is no space from the top
				return false
			end

			local name = core.get_meta(pos):get_string("name")
			if name == "" then
				name = core.get_meta(pos_other):get_string("name")
			end
			if name == "" then
				name = readablename .. " " .. S("Large Chest")
			end

			core.show_formspec(clicker:get_player_name(),
				sf("colored_chests:%s_%s_%s_%s", canonical_basename .. "_" .. colorname , pos.x, pos.y, pos.z),
				table.concat({
					"formspec_version[4]",
					"size[11.75,14.15]",

					"label[0.375,0.375;" .. F(C(mcl_formspec.label_color, name)) .. "]",
					mcl_formspec.get_itemslot_bg_v4(0.375, 0.75, 9, 3),
					sf("list[nodemeta:%s,%s,%s;main;0.375,0.75;9,3;]", pos.x, pos.y, pos.z),
					mcl_formspec.get_itemslot_bg_v4(0.375, 4.5, 9, 3),
					sf("list[nodemeta:%s,%s,%s;main;0.375,4.5;9,3;]", pos_other.x, pos_other.y, pos_other.z),
					"label[0.375,8.45;" .. F(C(mcl_formspec.label_color, S("Inventory"))) .. "]",
					mcl_formspec.get_itemslot_bg_v4(0.375, 8.825, 9, 3),
					"list[current_player;main;0.375,8.825;9,3;9]",

					mcl_formspec.get_itemslot_bg_v4(0.375, 12.775, 9, 1),
					"list[current_player;main;0.375,12.775;9,1;]",

					--BEGIN OF LISTRING WORKAROUND
					"listring[current_player;main]",
					sf("listring[nodemeta:%s,%s,%s;input]", pos.x, pos.y, pos.z),
					--END OF LISTRING WORKAROUND
					"listring[current_player;main]" ..
					sf("listring[nodemeta:%s,%s,%s;main]", pos.x, pos.y, pos.z),
					"listring[current_player;main]",
					sf("listring[nodemeta:%s,%s,%s;main]", pos_other.x, pos_other.y, pos_other.z),
				})
			)

			if on_rightclick_addendum_left then
				on_rightclick_addendum_left(pos, node, clicker)
			end

			player_chest_open(clicker, pos, left_name, left_textures, node.param2, true, "default_chest",
				"mcl_chests_chest")
		end,
		_mcl_redstone = redstone,
		on_rotate = no_rotate,
	})

	core.register_node("colored_chests:" .. basename .. "_" .. colorname .. "_right", {
		drawtype = "nodebox",
		paramtype = "light",
		paramtype2 = "facedir",
		_mcl_baseitem = "colored_chests:"..basename .. "_" .. colorname ,
		node_box = {
			type = "fixed",
			fixed = { -0.5, -0.5, -0.4375, 0.4375, 0.375, 0.4375 },
		},
		tiles = { "blank.png^[resize:16x16" },
		use_texture_alpha = "blend",
		groups = {
			handy = 1,
			axey = 1,
			container = 6,
			not_in_creative_inventory = 1,
			material_wood = 1,
			flammable = -1,
			double_chest = 2,
			pathfinder_partial = 2,
			piglin_protected = 1,
		},
		drop = drop,
		is_ground_content = false,
		sounds = mcl_sounds.node_sound_wood_defaults(),
		on_punch = mcl_colored_chests.on_punch,
		on_construct = function(pos)
			local n = core.get_node(pos)
			local param2 = n.param2
			local p = mcl_util.get_double_container_neighbor_pos(pos, param2, "right")
			if not p or core.get_node(p).name ~= "colored_chests:" .. canonical_basename .. "_" .. colorname .. "_left" then
				n.name = "colored_chests:" .. canonical_basename .. "_" .. colorname .. "_small"
				core.swap_node(pos, n)
			end
		end,
		after_place_node = function(pos, _, itemstack, _)
			core.get_meta(pos):set_string("name", itemstack:get_meta():get_string("name"))
		end,
		on_destruct = function(pos)
			local n = core.get_node(pos)
			if n.name == small_name then
				return
			end

			close_forms(canonical_basename, pos)

			local param2 = n.param2
			local p = mcl_util.get_double_container_neighbor_pos(pos, param2, "right")
			if not p or core.get_node(p).name ~= "colored_chests:" .. basename .. "_" .. colorname .. "_left" then
				return
			end
			close_forms(canonical_basename, p)

			core.swap_node(p, { name = small_name, param2 = param2 })
			create_entity(p, small_name, small_textures, param2, false, "default_chest", "mcl_chests_chest", "chest")
		end,
		after_dig_node = drop_items_chest,
		on_blast = on_chest_blast,
		allow_metadata_inventory_move = protection_check_move,
		allow_metadata_inventory_take = protection_check_put_take,
		allow_metadata_inventory_put = function(pos, listname, _, stack, player)
			local other_pos = mcl_util.get_double_container_neighbor_pos(pos, core.get_node(pos).param2, "right")
			if core.get_item_group(core.get_node(other_pos).name, "double_chest") == 0 then
				return 0
			end
			local name = player:get_player_name()
			if core.is_protected(pos, name) then
				core.record_protection_violation(pos, name)
				return 0
				-- BEGIN OF LISTRING WORKAROUND
			elseif listname == "input" then
				local other_inv = core.get_inventory({ type = "node", pos = other_pos })
				local inv = core.get_inventory({ type = "node", pos = pos })
				return limit_put(stack, other_inv, inv)
				-- END OF LISTRING WORKAROUND
			else
				return stack:get_count()
			end
		end,
		on_metadata_inventory_move = function(pos, _, _, _, _, _, player)
			core.log("action", player:get_player_name() ..
				" moves stuff in chest at " .. core.pos_to_string(pos))
		end,
		on_metadata_inventory_put = function(pos, listname, _, stack, player)
			core.log("action", player:get_player_name() ..
				" moves stuff to chest at " .. core.pos_to_string(pos))
			local other_pos = mcl_util.get_double_container_neighbor_pos(pos, core.get_node(pos).param2, "right")
			-- BEGIN OF LISTRING WORKAROUND
			if listname == "input" then
				local other_inv = core.get_inventory({ type = "node", pos = other_pos })
				local inv = core.get_inventory({ type = "node", pos = pos })

				inv:set_stack("input", 1, nil)

				double_chest_add_item(other_inv, inv, "main", stack)
			end
			-- END OF LISTRING WORKAROUND
			mcl_colored_chests.update_comparators(pos)
			mcl_colored_chests.update_comparators(other_pos)
		end,
		on_metadata_inventory_take = function(pos, _, _, _, player)
			core.log("action", player:get_player_name() ..
				" takes stuff from chest at " .. core.pos_to_string(pos))
			local other_pos = mcl_util.get_double_container_neighbor_pos(pos, core.get_node(pos).param2, "right")
			mcl_colored_chests.update_comparators(pos)
			mcl_colored_chests.update_comparators(other_pos)
		end,
		_mcl_hardness = 2.5,

		on_rightclick = function(pos, node, clicker)
			local pos_other = mcl_util.get_double_container_neighbor_pos(pos, node.param2, "right")
			local def =  core.registered_nodes[core.get_node(vector.offset(pos, 0, 1, 0)).name]
			local def_other = core.registered_nodes[core.get_node(vector.offset(pos_other, 0, 1, 0)).name]
			if not def or def.groups.opaque == 1
				or not def_other or def_other.groups.opaque
				== 1 then
				-- won't open if there is no space from the top
				return false
			end

			local name = core.get_meta(pos_other):get_string("name")
			if name == "" then
				name = core.get_meta(pos):get_string("name")
			end
			if name == "" then
				name = readablename .. " " .. S("Large Chest")
			end

			core.show_formspec(clicker:get_player_name(),
				sf("colored_chests:%s_%s_%s_%s", canonical_basename .. "_" .. colorname , pos.x, pos.y, pos.z),
				table.concat({
					"formspec_version[4]",
					"size[11.75,14.15]",

					"label[0.375,0.375;" .. F(C(mcl_formspec.label_color, name)) .. "]",
					mcl_formspec.get_itemslot_bg_v4(0.375, 0.75, 9, 3),
					sf("list[nodemeta:%s,%s,%s;main;0.375,0.75;9,3;]", pos_other.x, pos_other.y, pos_other.z),
					mcl_formspec.get_itemslot_bg_v4(0.375, 4.5, 9, 3),
					sf("list[nodemeta:%s,%s,%s;main;0.375,4.5;9,3;]", pos.x, pos.y, pos.z),
					"label[0.375,8.45;" .. F(C(mcl_formspec.label_color, S("Inventory"))) .. "]",
					mcl_formspec.get_itemslot_bg_v4(0.375, 8.825, 9, 3),
					"list[current_player;main;0.375,8.825;9,3;9]",

					mcl_formspec.get_itemslot_bg_v4(0.375, 12.775, 9, 1),
					"list[current_player;main;0.375,12.775;9,1;]",

					--BEGIN OF LISTRING WORKAROUND
					"listring[current_player;main]",
					sf("listring[nodemeta:%s,%s,%s;input]", pos.x, pos.y, pos.z),
					--END OF LISTRING WORKAROUND
					"listring[current_player;main]" ..
					sf("listring[nodemeta:%s,%s,%s;main]", pos_other.x, pos_other.y, pos_other.z),
					"listring[current_player;main]",
					sf("listring[nodemeta:%s,%s,%s;main]", pos.x, pos.y, pos.z),
				})
			)

			if on_rightclick_addendum_right then
				on_rightclick_addendum_right(pos, node, clicker)
			end

			player_chest_open(clicker, pos_other, left_name, left_textures, node.param2, true, "default_chest",
				"mcl_chests_chest")
		end,
		_mcl_redstone = redstone,
		on_rotate = no_rotate,
	})

	if mod_doc then
		doc.add_entry_alias("nodes", small_name, "nodes", "colored_chests:" .. basename .. "_" .. colorname .. "_left")
		doc.add_entry_alias("nodes", small_name, "nodes", "colored_chests:" .. basename .. "_" .. colorname .. "_right")
	end

	-- END OF register_chest FUNCTION BODY
end

local chestusage = S("To access its inventory, rightclick it. When broken, the items will drop out.")

for k,v in pairs(mcl_dyes.colors) do
register_chest("chest",
	v.readable_name .. " " .. S("Colored Chest"),
	--S("Colored Chest"),
	S("Chests are containers which provide 27 inventory slots. Chests can be turned into large chests with double the capacity by placing two chests next to each other."),
	chestusage,
	S("27 inventory slots") .. "\n" .. S("Can be combined to a large chest"),
	{
		--small = { name = tiles_chest_normal_small_str, color = "#ffff0020" },
		--small = co(tiles_chest_normal_small,"#ffff00:50"),
		--double = co(tiles_chest_normal_double,"#ffff00:50"),
		small = co(tiles_chest_normal_small,v.rgb), -- .. ":50"),
		double = co(tiles_chest_normal_double,v.rgb), -- .. ":50"),
		inv = { "default_chest_top.png", "mcl_chests_chest_bottom.png",
			"mcl_chests_chest_right.png", "mcl_chests_chest_left.png",
			"mcl_chests_chest_back.png", "default_chest_front.png" },
	},
	false,
	nil,
	nil,
	nil,
	nil,
	nil,
	nil,
	k,
	v.readable_name
)

-- use colored planks
if mod_mcl_decor then
	local thiswood = "mcl_decor:" .. k .. "_planks"
	core.register_craft({
		output = "colored_chests:chest_" .. k,
		recipe = {
			{ thiswood, thiswood, thiswood },
			{ thiswood,       "", thiswood },
			{ thiswood, thiswood, thiswood }
		},
	})
end

local thisdye = moddye .. k
core.register_craft({
	output = "colored_chests:chest_" .. k,
	recipe = {
		{ thisdye, thisdye, thisdye },
		{ thisdye, "group:chest", thisdye },
		{ thisdye, thisdye, thisdye }
	},
})
core.register_craft({
	output = "colored_chests:chest_" .. k,
	recipe = {
		{ thisdye, thisdye, thisdye },
		{ thisdye, "mcl_chests:chest", thisdye },
		{ thisdye, thisdye, thisdye }
	},
})

end

-- Disable chest when it has been closed
core.register_on_player_receive_fields(function(player, formname, fields)
	if formname:find("colored_chests:") == 1 then
		if fields.quit then
			player_chest_close(player)
		end
	end
end)

core.register_on_leaveplayer(function(player)
	player_chest_close(player)
end)

core.register_craft({
	output = "colored_chests:chest",
	recipe = {
		{ "group:wood", "group:wood", "group:wood" },
		{ "group:wood", "",           "group:wood" },
		{ "group:wood", "group:wood", "group:wood" },
	},
})

local function select_and_spawn_entity(pos, node)
	local node_name = node.name
	local node_def = core.registered_nodes[node_name]
	local double_chest = core.get_item_group(node_name, "double_chest") > 0
	if not animate_chests and not double_chest then
		return
	end

	find_or_create_entity(pos, node_name, node_def._chest_entity_textures, node.param2, double_chest, node_def._chest_entity_sound, node_def._chest_entity_mesh, node_def._chest_entity_animation_type)
end

function mcl_colored_chests.is_opened (chest)
	for k, v in open_chests do
		if vector.equal (v.pos, chest)
			and core.get_player_by_name (k) then
			return true
		end
	end
	return false
end

core.register_lbm({
	label = "Spawn Chest entities",
	name = "colored_chests:spawn_chest_entities",
	nodenames = { "group:chest_entity" },
	run_at_every_load = true,
	action = select_and_spawn_entity,
})

core.register_lbm({
	label = "Replace old chest nodes",
	name = "colored_chests:replace_old",
	nodenames = { "colored_chests:chest" },
	run_at_every_load = true,
	action = function(pos, node)
		local node_name = node.name
		node.name = node_name .. "_small"
		core.swap_node(pos, node)
		select_and_spawn_entity(pos, node)
	end
})
