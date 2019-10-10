-- Mountain digger fortress, protect the locomotive! -- by MewMew

require "modules.biter_noms_you"
require "modules.biter_evasion_hp_increaser"
require "modules.wave_defense.main"
--require "modules.dense_rocks"
require "functions.soft_reset"
require "functions.basic_markets"
require "modules.biters_yield_coins"
require "modules.no_deconstruction_of_neutral_entities"
require "modules.rocks_broken_paint_tiles"
require "modules.rocks_heal_over_time"
require "modules.rocks_yield_ore_veins"
require "modules.spawners_contain_biters"
require "modules.map_info"
require "modules.rpg"

global.map_info = {}
global.map_info.main_caption = "Mountain Fortress"
global.map_info.sub_caption =  "    ..diggy diggy choo choo.."
global.map_info.text = [[
	The biters have catched the scent of fish in the cargo wagon.
	Guide the choo into the mountain and protect it as long as possible!
	This however will not be an easy task,
	since their strength and resistance increases constantly over time.
	
	Delve deep for greater treasures, but also face increased dangers.
	Mining productivity research, will overhaul your mining equipment,
	reinforcing your pickaxe as well as increasing the size of your backpack.
	
	As you dig, you will encounter black bedrock that is just too solid for your pickaxe.
	Some explosives could even break through the impassable dark rock.
	All they need is a container and a well aimed shot.
]]

require "maps.mountain_fortress_v2.market"
require "maps.mountain_fortress_v2.treasure"
require "maps.mountain_fortress_v2.terrain"
require "maps.mountain_fortress_v2.locomotive"
require "maps.mountain_fortress_v2.explosives"
require "maps.mountain_fortress_v2.flamethrower_nerf"

local starting_items = {['pistol'] = 1, ['firearm-magazine'] = 16, ['rail'] = 16, ['wood'] = 16}
local treasure_chest_messages = {
	"You notice an old crate within the rubble. It's filled with treasure!",
	"You find a chest underneath the broken rocks. It's filled with goodies!",
	"We has found the precious!",
}

local function get_gen_settings()
	local map = {
		["seed"] = math.random(1, 1000000),
		["width"] = 1536,
		["water"] = 0.001,
		["starting_area"] = 1,
		["cliff_settings"] = {cliff_elevation_interval = 0, cliff_elevation_0 = 0},
		["default_enable_all_autoplace_controls"] = true,
		["autoplace_settings"] = {
			["entity"] = {treat_missing_as_default = false},
			["tile"] = {treat_missing_as_default = true},
			["decorative"] = {treat_missing_as_default = true},
		},
	}
	return map
end

function reset_map()
	global.chunk_queue = {}
	
	if not global.active_surface then
		global.active_surface = game.create_surface("mountain_fortress", get_gen_settings())
	else
		game.forces.player.set_spawn_position({-2, 16}, global.active_surface)
		global.active_surface = soft_reset_map(global.active_surface, get_gen_settings(), starting_items)
	end
	
	global.active_surface.request_to_generate_chunks({0,0}, 2)
	global.active_surface.force_generate_chunk_requests()
	
	for x = -768 + 32, 768 - 32, 32 do
		global.active_surface.request_to_generate_chunks({x, 96}, 1)
		global.active_surface.force_generate_chunk_requests()
	end
	
	game.map_settings.enemy_evolution.destroy_factor = 0
	game.map_settings.enemy_evolution.pollution_factor = 0	
	game.map_settings.enemy_evolution.time_factor = 0
	game.map_settings.enemy_expansion.enabled = true
	game.map_settings.enemy_expansion.max_expansion_cooldown = 1800
	game.map_settings.enemy_expansion.min_expansion_cooldown = 1800
	game.map_settings.enemy_expansion.settler_group_max_size = 16
	game.map_settings.enemy_expansion.settler_group_min_size = 32
	game.map_settings.pollution.enabled = false
	
	game.forces.player.technologies["railway"].researched = true
	game.forces.player.set_spawn_position({-2, 16}, global.active_surface)
	
	locomotive_spawn(global.active_surface, {x = 0, y = 16})
	
	reset_wave_defense()
	global.wave_defense.surface = global.active_surface
	global.wave_defense.target = global.locomotive_cargo	
	
	global.wave_defense.game_lost = false
end

local function protect_train(event)
	if event.entity.force.index ~= 1 then return end --Player Force
	if event.entity == global.locomotive or event.entity == global.locomotive_cargo then
		if event.cause then
			if event.cause.force.index == 2 then
				return
			end
		end
		event.entity.health = event.entity.health + event.final_damage_amount
	end
end

local function neutral_force_player_damage_resistance(event)
	if event.entity.force.index ~= 3 then return end  -- Neutral Force
	if event.cause then
		if event.cause.valid then
			if event.cause.force.index == 2 then -- Enemy Force
				return
			end
		end
	end
	if event.entity.health <= event.final_damage_amount then				
		event.entity.die("neutral")
		return
	end
	event.entity.health = event.entity.health + (event.final_damage_amount * 0.5)		
end

local function biters_chew_rocks_faster(event)
	if event.entity.force.index ~= 3 then return end --Neutral Force
	if not event.cause then return end
	if not event.cause.valid then return end
	if event.cause.force.index ~= 2 then return end --Enemy Force
	local bonus_damage =  event.final_damage_amount * math.abs(global.wave_defense.threat) * 0.0003
	event.entity.health = event.entity.health - bonus_damage
end

local function hidden_biter(entity)
	wave_defense_set_biter_raffle(math.sqrt(entity.position.x ^ 2 + entity.position.y ^ 2) * 0.45)
	entity.surface.create_entity({name = wave_defense_roll_biter_name(), position = entity.position})
end

local function hidden_treasure(event)
	if math.random(1, 320) ~= 1 then return end
	if event.entity.type ~= "simple-entity" then return end
	game.players[event.player_index].print(treasure_chest_messages[math.random(1, #treasure_chest_messages)], {r=0.98, g=0.66, b=0.22})
	treasure_chest(event.entity.surface, event.entity.position)
end

local function on_player_mined_entity(event)
	if not event.entity.valid then	return end	
	if event.entity.force.index == 3 then
		if math.random(1,32) == 1 then
			hidden_biter(event.entity)
			return
		end
		hidden_treasure(event)
	end
end

local function on_entity_died(event)
	if not event.entity.valid then	return end
	if event.entity == global.locomotive_cargo then	
		game.print("The cargo was destroyed!")	
		global.wave_defense.game_lost = true 
		global.game_reset_tick = game.tick + 1800
		for _, player in pairs(game.connected_players) do
			player.play_sound{path="utility/game_lost", volume_modifier=0.75}
		end
		event.entity.surface.spill_item_stack(event.entity.position,{name = "raw-fish", count = 512}, false)
		--rpg_reset_all_players()
		return 
	end
	
	if event.cause then
		if event.cause.valid then
			if event.cause.force.index == 2 or event.cause.force.index == 3 then return end 
		end
	end
	if event.entity.force.index == 3 then
		if math.random(1,8) == 1 then
			hidden_biter(event.entity) 
		end
	end
end

local function on_entity_damaged(event)
	if not event.entity.valid then	return end	
	protect_train(event)
	
	if not event.entity.health then return end
	biters_chew_rocks_faster(event)
	--neutral_force_player_damage_resistance(event)
end

local function on_research_finished(event)
	event.research.force.character_inventory_slots_bonus = game.forces.player.mining_drill_productivity_bonus * 50 -- +5 Slots / level
	local mining_speed_bonus = game.forces.player.mining_drill_productivity_bonus * 5 -- +50% speed / level
	if event.research.force.technologies["steel-axe"].researched then mining_speed_bonus = mining_speed_bonus + 1 end -- +100% speed for steel-axe research
	event.research.force.manual_mining_speed_modifier = mining_speed_bonus
end

local function on_player_joined_game(event)
	local player = game.players[event.player_index]	
	
	if player.online_time == 0 then
		player.teleport(global.active_surface.find_non_colliding_position("character", game.forces.player.get_spawn_position(global.active_surface), 3, 0.5), global.active_surface)
		for item, amount in pairs(starting_items) do
			player.insert({name = item, count = amount})
		end
	end
	
	if player.surface.index ~= global.active_surface.index then
		player.teleport(global.active_surface.find_non_colliding_position("character", game.forces.player.get_spawn_position(global.active_surface), 3, 0.5), global.active_surface)
	end
end

local function on_init(surface)
	global.rocks_yield_ore_maximum_amount = 250
	global.rocks_yield_ore_base_amount = 50
	global.rocks_yield_ore_distance_modifier = 0.04
	reset_map()
end

local event = require 'utils.event'
event.on_init(on_init)
event.add(defines.events.on_entity_damaged, on_entity_damaged)
event.add(defines.events.on_entity_died, on_entity_died)
event.add(defines.events.on_player_mined_entity, on_player_mined_entity)
event.add(defines.events.on_research_finished, on_research_finished)
event.add(defines.events.on_player_joined_game, on_player_joined_game)

require "modules.rocks_yield_ore"