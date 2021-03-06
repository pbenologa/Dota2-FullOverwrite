-------------------------------------------------------------------------------
--- AUTHOR: Nostrademous
--- GITHUB REPO: https://github.com/Nostrademous/Dota2-FullOverwrite
------------------------------------------------------------------------------- 

_G._savedEnv = getfenv()
module( "team_think", package.seeall )

require( GetScriptDirectory().."/buildings_status" )
require( GetScriptDirectory().."/global_game_state" )

local gHeroVar = require( GetScriptDirectory().."/global_hero_data" )
local utils = require( GetScriptDirectory().."/utility" )
local enemyData = require( GetScriptDirectory().."/enemy_data" )

local function setHeroVar(id, var, value)
    gHeroVar.SetVar(id, var, value)
end

local function getHeroVar(id, var)
    return gHeroVar.GetVar(id, var)
end

local glyphTimer = -1000

-- This is at top as all item purchases are Immediate actions,
-- and therefore won't affect any other decision making.
-- Intent is to smartly determine when we should use our Glyph
-- to protect our towers.
function ConsiderGlyphUse()
    local vulnerableTowers = buildings_status.GetDestroyableTowers(GetTeam())
    for i, building_id in pairs(vulnerableTowers) do
        local tower = buildings_status.GetHandle(GetTeam(), building_id)

        if tower:GetHealth() < math.max(tower:GetMaxHealth()*0.15, 165) and tower:TimeSinceDamagedByAnyHero() < 3
            and tower:TimeSinceDamagedByCreep() < 3 then
            if GetGlyphCooldown() == 0 and (GameTime() - glyphTimer > 1.0) then
                GetBot():ActionImmediate_Glyph()
                glyphTimer = GameTime()
            end
        end
    end
end

-- This is at top as all item purchases are Immediate actions,
-- and therefore won't affect any other decision making.
-- Intent is to smartly determine which heroes should purchases
-- Team items like Tome of Knowledge, Wards, Dust/Sentry, and
-- even stuff like picking up Gem, Aegis, Cheese, etc.
function ConsiderTeamWideItemAcquisition(playerAssignment)
    local listAlly = GetUnitList(UNIT_LIST_ALLIED_HEROES)

    -- only add TeamBuy if list is 'nil' or empty
    local lowestLevelAlly = nil
    for _, ally in pairs(listAlly) do
        if not ally:IsIllusion() and ally:IsBot() then
            if not lowestLevelAlly or lowestLevelAlly:GetLevel() > ally:GetLevel() then
                lowestLevelAlly = ally
            end
        end
    end

    if lowestLevelAlly and #getHeroVar(lowestLevelAlly:GetPlayerID(), "TeamBuy") == 0 then
        local tomes = GetItemStockCount("item_tome_of_knowledge")
        while tomes > 0 do
            utils.myPrint("Buying Tome of Knowledge for '"..utils.GetHeroName(lowestLevelAlly).."'")
            table.insert(getHeroVar(lowestLevelAlly:GetPlayerID(), "TeamBuy"),  1, "item_tome_of_knowledge")
            tomes = tomes - 1
        end
    end
end

-- This is at top as all courier actions are Immediate actions,
-- and therefore won't affect any other decision making.
-- Intent is to make courier use more efficient by aligning
-- the purchases of multiple localized heroes together.
function ConsiderTeamWideCourierUse()
end

-- This is a fight orchestration evaluator. It will determine,
-- based on the global picture and location of all enemy and
-- friendly units, whether we should pick a fight, whether in
-- the middle of nowhere, as part of a push/defense of a lane,
-- or even as part of an ally defense. All Heroes involved will
-- have their actionQueues filled out by this function and
-- their only responsibility will be to do those actions. Note,
-- heroes with Global skills (Invoker Sun Strike, Zeus Ult, etc.)
-- can be part of this without actually being present in the area.
function ConsiderTeamFightAssignment(playerActionQueues)
    global_game_state.GlobalFightDetermination()
end

-- Determine which lanes should be pushed and which Heroes should
-- be part of the push.
function ConsiderTeamLanePush()
end

-- Determine which lanes should be defended and which Heroes should
-- be part of the defense.
function ConsiderTeamLaneDefense()
    local lane, building, numEnemies = global_game_state.DetectEnemyPush()
    
    if lane == nil or building == nil or numEnemies == nil then return end
    
    local hBuilding = buildings_status.GetHandle(GetTeam(), building)
    
    local listAlliesCanReachBuilding = {}
    local listAlliesCanTPToBuildling = {}
    
    local listAlly = GetUnitList(UNIT_LIST_ALLIED_HEROES)
    for _, ally in pairs(listAlly) do
        if not ally:IsIllusion() and ally:IsBot() then
            if lane and (not hBuilding == nil or hBuilding:TimeSinceDamagedByAnyHero() > 5.0) then
                if ally:GetHealth()/ally:GetMaxHealth() >= 0.5 then
                    local distFromBuilding = GetUnitToUnitDistance(ally, hBuilding)
                    local timeToReachBuilding = distFromBuilding/ally:GetCurrentMovementSpeed()

                    if timeToReachBuilding <= 5.0 then
                        table.insert(listAlliesCanReachBuilding, ally)
                    else
                        local haveTP = utils.HaveItem(ally, "item_tpscroll")
                        if haveTP and haveTP:IsFullyCastable() then
                            table.insert(listAlliesCanTPToBuildling, ally)
                        end
                    end
                end
            end
        end
    end
    
    if (#listAlliesCanReachBuilding + #listAlliesCanTPToBuildling) >= (numEnemies - 1) then
        local numGoing = 0
        for _, ally in pairs(listAlliesCanReachBuilding) do
            gHeroVar.SetVar(ally:GetPlayerID(), "DoDefendLane", {lane, building, numEnemies})
            numGoing = numGoing + 1
            if numGoing >= (numEnemies - 1) then break end
        end
        for _, ally in pairs(listAlliesCanTPToBuildling) do
            gHeroVar.SetVar(ally:GetPlayerID(), "DoDefendLane", {lane, building, numEnemies})
            numGoing = numGoing + 1
            if numGoing >= (numEnemies - 1) then break end
        end
    end
end

-- Determine which hero (based on their role) should farm where. By
-- default it is best to probably leave their default lane assignment,
-- but if they are getting killed repeatedly we could rotate them. This
-- also considers jungling assignments and lane rotations.
function ConsiderTeamFarmDesignation()
end

-- Determine if we should Roshan and which Heroes should be part of it.
function ConsiderTeamRoshan()
    local numAlive = enemyData.GetNumAlive()

    local isRoshanAlive = DotaTime() - GetRoshanKillTime() > (11*60)

    if (numAlive < 3 and (GetRoshanKillTime() == 0 or isRoshanAlive)) then
        -- FIXME: Implement
    end
end

-- Determine if we should seek out a specific enemy for a kill attempt
-- and which Heroes should be part of the kill.
function ConsiderTeamRoam()
end

-- If we see a rune, determine if any specific Heroes should get it 
-- (to fill a bottle for example). If not, the hero that saw it will 
-- pick it up. Also consider obtaining Rune vision if lacking.
function ConsiderTeamRune(playerAssignment)
    local listAlly = GetUnitList(UNIT_LIST_ALLIED_HEROES)
    
    for _, rune in pairs(constants.RuneSpots) do
        if GetRuneStatus(rune) == RUNE_STATUS_AVAILABLE then
            local runeLoc = GetRuneSpawnLocation(rune)
            local bestDist = 5000
            local bestAlly = nil
            for _, ally in pairs(listAlly) do
                if ally:IsAlive() and not ally:IsIllusion() and ally:IsBot() then
                    local dist = GetUnitToLocationDistance(ally, runeLoc)
                    if dist < bestDist then
                        bestDist = dist
                        bestAlly = ally
                    end
                end
            end
            
            if bestAlly then
                playerAssignment[bestAlly:GetPlayerID()].GetRune = {rune, runeLoc}
            end
        end
    end
end

-- If any of our Heroes needs to heal up, Shrines are an option.
-- However, we should be smart about the use and see if any other 
-- friends could benefit as well rather than just being selfish.
function ConsiderTeamShrine(playerAssignment)
    local bestShrine = nil
    local distToShrine = 100000
    local Team = GetTeam()
    
    local listAlly = GetUnitList(UNIT_LIST_ALLIED_HEROES)
    local shrineUseList = {}
    
    -- determine which allies need to use the shrine and which shrine is best
    -- for them
    for _, ally in pairs(listAlly) do
        if ally:IsAlive() and ally:IsBot() and not ally:IsIllusion() and ally:GetHealth()/ally:GetMaxHealth() < 0.3 
            and playerAssignment[ally:GetPlayerID()].UseShrine == nil then
            local SJ1 = GetShrine(Team, SHRINE_JUNGLE_1)
            if SJ1 and SJ1:GetHealth() > 0 and GetShrineCooldown(SJ1) == 0 then
                local dist = GetUnitToUnitDistance(ally, SJ1)
                if dist < distToShrine then
                    distToShrine = dist
                    bestShrine = SJ1
                end
            end
            local SJ2 = GetShrine(Team, SHRINE_JUNGLE_2)
            if SJ2 and SJ2:GetHealth() > 0 and GetShrineCooldown(SJ2) == 0 then
                local dist = GetUnitToUnitDistance(ally, SJ2)
                if dist < distToShrine then
                    distToShrine = dist
                    bestShrine = SJ2
                end
            end
            local SB1 = GetShrine(Team, SHRINE_BASE_1)
            if SB1 and SB1:GetHealth() > 0 and GetShrineCooldown(SB1) == 0 then
                local dist = GetUnitToUnitDistance(ally, SB1)
                if dist < distToShrine then
                    distToShrine = dist
                    bestShrine = SB1
                end
            end
            local SB2 = GetShrine(Team, SHRINE_BASE_2)
            if SB2 and SB2:GetHealth() > 0 and GetShrineCooldown(SB2) == 0 then
                local dist = GetUnitToUnitDistance(ally, SB2)
                if dist < distToShrine then
                    distToShrine = dist
                    bestShrine = SB2
                end
            end
            local SB3 = GetShrine(Team, SHRINE_BASE_3)
            if SB3 and SB3:GetHealth() > 0 and GetShrineCooldown(SB3) == 0 then
                local dist = GetUnitToUnitDistance(ally, SB3)
                if dist < distToShrine then
                    distToShrine = dist
                    bestShrine = SB3
                end
            end
            local SB4 = GetShrine(Team, SHRINE_BASE_4)
            if SB4 and SB4:GetHealth() > 0 and GetShrineCooldown(SB4) == 0 then
                local dist = GetUnitToUnitDistance(ally, SB4)
                if dist < distToShrine then
                    distToShrine = dist
                    bestShrine = SB4
                end
            end
            local SB5 = GetShrine(Team, SHRINE_BASE_5)
            if SB5 and SB5:GetHealth() > 0 and GetShrineCooldown(SB5) == 0 then
                local dist = GetUnitToUnitDistance(ally, SB5)
                if dist < distToShrine then
                    distToShrine = dist
                    bestShrine = SB5
                end
            end
            
            if bestShrine then
                if shrineUseList[tostring(bestShrine)] == nil then
                    shrineUseList[tostring(bestShrine)] = { shrine=bestShrine, players={} }
                end
                
                utils.myPrint("shrineUseList["..tostring(bestShrine).."] is best for: ", ally:GetPlayerID())
                table.insert(shrineUseList[tostring(bestShrine)].players, ally:GetPlayerID())
            end
        end
    end
    
    -- Now that we have assigned each player to the best shrine we need to set the player assignments
    -- telling the hero which shrine to go to and for how many people who should wait
    for name, value in pairs(shrineUseList) do
        for _, ally in pairs(listAlly) do
            --utils.myPrint("Checking player '", ally:GetPlayerID(), "' for shrine ", name)
            if utils.InTable(value.players, ally:GetPlayerID()) then
                --utils.myPrint("Assigning ", utils.GetHeroName(ally), " to shrine: ", name)
                playerAssignment[ally:GetPlayerID()].UseShrine = {shrine=value.shrine, allies=value.players}
            end
        end
    end
end

for k,v in pairs( team_think ) do _G._savedEnv[k] = v end
