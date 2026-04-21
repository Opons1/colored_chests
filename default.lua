local S = core.get_translator("colored_chests")
local modpath = core.get_modpath("colored_chests")
colored_chests = {
	colors = {
		{"white",      "White"},
		{"red",        "Red"},
		{"dark_red",    "Dark red", true, "red", true},
		{"brown",      "Brown"},
		{"orange",     "Orange"},
		{"yellow",     "Yellow"},
		{"green",      "Green"},
		{"dark_green", "Dark Green", true, "green"},
		{"cyan",       "Cyan"},
		{"blue",       "Blue"},
		{"dark_blue",  "Dark Blue", true, "blue", true},
		{"pink",       "Pink"},
		{"violet",     "Violet"},
		{"grey",       "Grey"},
		{"dark_grey",  "Dark Grey", true, "grey"},
		{"black",      "Black"},
	}
}
dofile(modpath .."/api.lua")

for _, row in ipairs(colored_chests.colors) do
	name = row[1]
	desc = row[2]
	dark = (row[3] or false)
	no_dye = (row[5] or false)
	if dark then
		lightname = row[4]
	end
	for _, locked in ipairs({false, true}) do
		if (locked) then
			colored_chests.chest.register_chest("colored_chests:locked_"..name.."_chest", {
				description = S(desc) .." ".. S("Chest"),
				tiles = {
					"colored_chests_"..name.."_top.png",
					"colored_chests_"..name.."_top.png",
					"colored_chests_"..name.."_side.png",
					"colored_chests_"..name.."_side.png",
					"colored_chests_"..name.."_lock.png",
					"colored_chests_"..name.."_inside.png"
				},
				sounds = default.node_sound_wood_defaults(),
				protected = locked,
				sound_open = "default_chest_open",
				sound_close = "default_chest_close",
				groups = {choppy = 2, oddly_breakable_by_hand = 2, colored_chest = 1},
			})
			core.register_craft( {
				type = "shapeless",
				output = "colored_chests:locked_"..name.."_chest",
				recipe = {"colored_chests:"..name.."_chest", "default:steel_ingot"},
			})
			core.register_craft({
				type = "fuel",
				recipe = "colored_chests:"..name.."_chest",
				burntime = 25,
			})
		else
			colored_chests.chest.register_chest("colored_chests:"..name.."_chest", {
				description = S(desc) .." ".. S("Chest"),
				tiles = {
					"colored_chests_"..name.."_top.png",
					"colored_chests_"..name.."_top.png",
					"colored_chests_"..name.."_side.png",
					"colored_chests_"..name.."_side.png",
					"colored_chests_"..name.."_front.png",
					"colored_chests_"..name.."_inside.png"
				},
				sounds = default.node_sound_wood_defaults(),
				protected = locked,
				sound_open = "default_chest_open",
				sound_close = "default_chest_close",
				groups = {choppy = 2, oddly_breakable_by_hand = 2, colored_chest = 1},
			})
			core.register_craft({
				type = "fuel",
				recipe = "colored_chests:"..name.."_chest",
				burntime = 30,
			})
			if (dark) then
				if (not no_dye) then
					core.register_craft({
						output = "colored_chests:"..name.."_chest",
						recipe = {
							{"dye:"..name, "dye:"..name, "dye:"..name},
							{"dye:"..name, "colored_chests:"..lightname.."_chest", "dye:"..name},
							{"dye:"..name, "dye:"..name, "dye:"..name},
						}
					})
				else
					core.register_craft({
						output = "colored_chests:"..name.."_chest",
						recipe = {
							{"dye:"..lightname, "dye:"..lightname, "dye:"..lightname},
							{"dye:"..lightname, "colored_chests:"..lightname.."_chest", "dye:"..lightname},
							{"dye:"..lightname, "dye:"..lightname, "dye:"..lightname},
						}
					})
				end
			else
				core.register_craft({
					output = "colored_chests:"..name.."_chest",
					recipe = {
						{"dye:"..name, "dye:"..name, "dye:"..name},
						{"dye:"..name, "default:chest", "dye:"..name},
						{"dye:"..name, "dye:"..name, "dye:"..name},
					}
				})
				core.register_craft({
					output = "colored_chests:"..name.."_chest",
					recipe = {
						{"dye:"..name, "dye:"..name, "dye:"..name},
						{"dye:"..name, "group:colored_chest", "dye:"..name},
						{"dye:"..name, "dye:"..name, "dye:"..name},
					}
				})
			end
		end
	end
end