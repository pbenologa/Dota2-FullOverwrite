-------------------------------------------------------------------------------
--- AUTHOR: Nostrademous
--- GITHUB REPO: https://github.com/Nostrademous/Dota2-FullOverwrite
-------------------------------------------------------------------------------

require( GetScriptDirectory().."/constants" )
local utils = require( GetScriptDirectory().."/utility" )
local dt = require( GetScriptDirectory().."/decision_tree" )

local SKILL_Q = "antimage_mana_break";
local SKILL_W = "antimage_blink";
local SKILL_E = "antimage_spell_shield";
local SKILL_R = "antimage_mana_void"; 

local ABILITY1 = "special_bonus_strength_6"
local ABILITY2 = "special_bonus_attack_damage_20"
local ABILITY3 = "special_bonus_attack_speed_20"
local ABILITY4 = "special_bonus_hp_250"
local ABILITY5 = "special_bonus_evasion_15"
local ABILITY6 = "special_bonus_all_stats_10"
local ABILITY7 = "special_bonus_agility_25"
local ABILITY8 = "special_bonus_unique_antimage"

local AntimageAbilityPriority = {
	SKILL_W,    SKILL_Q,    SKILL_Q,    SKILL_E,    SKILL_Q,
    SKILL_R,    SKILL_Q,    SKILL_W,    SKILL_W,    ABILITY2,
    SKILL_W,    SKILL_R,    SKILL_E,    SKILL_E,    ABILITY4,
    SKILL_E,    SKILL_R,    ABILITY6, 	ABILITY8
};

local antimageActionQueue = { [1] = constants.ACTION_NONE }

AMBot = dt:new()

function AMBot:new(o)
	o = o or dt:new(o)
	setmetatable(o, self)
	self.__index = self
	return o
end

amBot = AMBot:new{prevTime = -997.0, actionQueue = antimageActionQueue, abilityPriority = AntimageAbilityPriority}
--AMBot:printInfo();

amBot.Init = false;

function amBot:RetreatAbility()
	local npcBot = GetBot()
	
	local blink = npcBot:GetAbilityByName("antimage_blink")
	if blink:IsFullyCastable() then
		return blink
	end
	return nil
end

function Think()
    local npcBot = GetBot();
	
	amBot:Think(npcBot);
end