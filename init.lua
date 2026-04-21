-- init.lua for colored_chests
-- Load default (minetest_game) or mineclonia/mineclone2

local MP = core.get_modpath(core.get_current_modname())
local gameid = core.get_game_info().id

if gameid == "mineclone2" or gameid == "mineclonia" then
	dofile(MP.."/mineclonia.lua")
else
	dofile(MP.."/default.lua")
end
