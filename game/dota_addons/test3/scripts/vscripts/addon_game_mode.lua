--[[
	Underscore prefix such as "_function()" denotes a local function and is used to improve readability
	Variable Prefix Examples
		"fl"	Float
		"n"		Int
		"v"		Table
		"b"		Boolean
		"h"     Handle
		"s"     String
]]

if CHoldoutGameMode == nil then
	_G.CHoldoutGameMode = class({}) 	
end

testMode=false
--testMode=true --减少刷兵间隔，增加初始金钱
goldTestMode=false
--goldTestMode=true --需要测试金币相关的内容

require( "holdout_game_round" )
require( "holdout_game_spawner" )
require( "util" )
require( "timers")
require( "spell_shop_UI")
require( "loot_controller" )
require( "difficulty_select_UI")
require( "global_setting")
require( "tws_util")
require( "libraries/notifications")
require( "item_ability/damage_filter")
require( "quest_system")
require( "vip/extra_particles")
require( "server/rank")
require( "server/detail")
require( "server/patreon")
require( "server/vip")
require( "server/taobao")
require( "server/gamesaver")
require( "vip/econ_manager")
require( 'vip/vip_reward')

-- Precache resources
-- Actually make the game mode when we activate
function Activate()
	CHoldoutGameMode:InitGameMode()
end

function Precache( context )
	PrecacheResource( "particle", "particles/items_fx/aegis_respawn.vpcf", context )	
	PrecacheResource( "particle", "particles/neutral_fx/roshan_spawn.vpcf", context )	
	PrecacheResource( "particle", "particles/items2_fx/veil_of_discord.vpcf", context )
	PrecacheResource( "particle_folder", "particles/frostivus_gameplay", context )
	PrecacheResource( "sound_folder", "sounds/weapons/creep/neutral", context )
    --Vip特效
    PrecacheResource( 'particle', 'particles/econ/courier/courier_trail_lava/courier_trail_lava.vpcf', context)
	PrecacheResource( 'particle', 'particles/econ/paltinum_baby_roshan/paltinum_baby_roshan.vpcf', context)
	PrecacheResource( 'particle', 'particles/econ/legion_wings/legion_wings.vpcf', context)
	PrecacheResource( 'particle', 'particles/econ/courier/courier_roshan_darkmoon/courier_roshan_darkmoon.vpcf', context)
	PrecacheResource( 'particle', 'particles/econ/courier/courier_roshan_darkmoon/courier_roshan_darkmoon_ground.vpcf', context)
    PrecacheResource( 'particle', 'particles/econ/courier/courier_roshan_frost/courier_roshan_frost_ambient.vpcf.vpcf', context)
    PrecacheResource( 'particle', 'particles/econ/courier/courier_greevil_green/courier_greevil_green_ambient_3.vpcf', context)
    PrecacheResource( 'particle', 'particles/econ/courier/courier_roshan_frost/courier_roshan_frost_ambient.vpcf', context)
    PrecacheResource( 'particle', 'particles/econ/courier/courier_sappling/courier_sappling_ambient_fly_lvl1.vpcf', context)
    PrecacheResource( 'particle', 'particles/econ/courier/courier_greevil_red/courier_greevil_red_ambient_3.vpcf', context)
    PrecacheResource( 'particle', 'particles/econ/courier/courier_trail_orbit/courier_trail_orbit.vpcf', context)


	PrecacheItemByNameSync( "item_tombstone", context )
	PrecacheItemByNameSync( "item_bag_of_gold_tws", context )
	PrecacheItemByNameSync( "item_skysong_blade", context )
	PrecacheItemByNameSync( "item_slippers_of_halcyon", context )
	PrecacheItemByNameSync( "item_greater_clarity", context )
	PrecacheItemByNameSync( "item_unholy", context )
	PrecacheItemByNameSync( "item_fallen_sword", context )
	PrecacheItemByNameSync( "item_redblade_armor", context )
	PrecacheItemByNameSync( "item_mage_shield_1", context )
	PrecacheItemByNameSync( "item_treasure_chest_1", context )
	PrecacheItemByNameSync( "item_treasure_chest_2", context )
	PrecacheItemByNameSync( "item_treasure_chest_3", context )
	PrecacheItemByNameSync( "item_treasure_chest_4", context )
	PrecacheItemByNameSync( "item_treasure_chest_5", context )
	PrecacheItemByNameSync( "item_treasure_chest_6", context )
	PrecacheItemByNameSync( "item_treasure_chest_7", context )
	PrecacheItemByNameSync( "item_treasure_chest_8", context )
	PrecacheUnitByNameAsync('npc_dota_tiny_1',function() end)
end



function CHoldoutGameMode:InitGameMode()

    GameRules:GetGameModeEntity().CHoldoutGameMode = self
    LinkLuaModifier("modifier_increase_total_damage_lua", "abilities/modifier_increase_total_damage_lua", LUA_MODIFIER_MOTION_NONE )
	Timers:start()
	LootController:ReadConfigration() 
	self.startflag=0 
	self.loseflag=0 
	self.last_live=5
	self._nRoundNumber = 1
	self._currentRound = nil
	self._flLastThinkGameTime = nil
	self.enchantress_already_die_flag=0
	self:_ReadGameConfiguration()
	self.itemSpawnIndex = 1
	self.flProgressTime=0 --记录progress阶段开始时间
	self.flDDadjust=1  --保存难度产生的伤害系数修正
	self.flDHPadjust=1  --保存难度产生的血量系数修正
	self.nTrialSetTime=12
	self.vipMap={}  --key是steamID vlaue是vip等级初始化是0
	self.steamIdMap={}  --key是steamID vlaue是nPlayerNumber
    self.vRoundSkip={}   --key是Round Number --value是跳关等级
    self.nGoldToCompensate=0 --跳关待补偿金币
    self.nExpToCompensate=0 --跳关待补偿经验
    self.bLoadFlag=false --读盘的游戏不能上天梯 全局变量
    self.bTestMode=testMode --全局变量存一下是不是测试模式
    self.nLoadTime = 0  --第几次读档
    self.vXPBeforeMap={}  --key是nPlayerId value是读档之前已经有的经验

    self.nTimeCost=0 --统计用时
    Timers:CreateTimer(function() --设置计时器
      self.nTimeCost=self.nTimeCost+1
      return 1.0
    end)


	GameRules:SetTimeOfDay( 0.75 )
	GameRules:SetCustomGameTeamMaxPlayers(DOTA_TEAM_BADGUYS, 0)
	GameRules:SetHeroRespawnEnabled( true )
	GameRules:GetGameModeEntity():SetFixedRespawnTime(99999999999)
	GameRules:SetUseUniversalShopMode( true )
	GameRules:SetHeroSelectionTime( 35.0 )
	GameRules:SetStrategyTime(0.0)
	GameRules:SetShowcaseTime(0.0)
    
	if testMode and not IsDedicatedServer() then  --单机模式 并且开启了测试
	  GameRules:SetPreGameTime( 3.0 )
	  if goldTestMode then
		  GameRules:SetGoldTickTime( 0.5 )
		  GameRules:SetGoldPerTick( 10000 )
	  end
	  self.nTrialSetTime=2
	  else
	  GameRules:SetPreGameTime( 15.0 )
	  GameRules:SetGoldTickTime( 60.0 )
	  GameRules:SetGoldPerTick( 0 )
    end
	GameRules:SetPostGameTime( 10.0 )
	GameRules:SetTreeRegrowTime( 35.0 )
	GameRules:SetHeroMinimapIconScale( 0.7 )
	GameRules:SetCreepMinimapIconScale( 0.7 )
	GameRules:SetRuneMinimapIconScale( 0.7 )
	GameRules:GetGameModeEntity():SetUseCustomHeroLevels( true )
    GameRules:GetGameModeEntity():SetCustomHeroMaxLevel( 999 )
	local xpTable = {}
	xpTable[0]=0
	xpTable[1]=200
	for i = 2, 1000 do
		xpTable[i] = xpTable[i-1]+i*100
	end
    GameRules:GetGameModeEntity():SetCustomXPRequiredToReachNextLevel( xpTable )
	GameRules:GetGameModeEntity():SetRemoveIllusionsOnDeath( true )
	GameRules:GetGameModeEntity():SetTopBarTeamValuesOverride( true )
	GameRules:GetGameModeEntity():SetTopBarTeamValuesVisible( false )
	-- Custom console commands
	Convars:RegisterCommand( "test_round", function(...) return self:_TestRoundConsoleCommand( ... ) end, "Test a round of holdout.", FCVAR_CHEAT )
	Convars:RegisterCommand( "status_report", function(...) return self:_StatusReportConsoleCommand( ... ) end, "Report the status of the current holdout game.", FCVAR_CHEAT )
	Convars:RegisterCommand( "list_modifiers", function(...) return self:_ListModifiers( ... ) end, "List modifiers of all hero.", FCVAR_CHEAT )
    --UI交互
    CustomGameEventManager:RegisterListener("AddAbility", Dynamic_Wrap(CHoldoutGameMode, 'AddAbility'))
    CustomGameEventManager:RegisterListener("RemoveAbility", Dynamic_Wrap(CHoldoutGameMode, 'RemoveAbility'))
    CustomGameEventManager:RegisterListener("LevelUpAttribute", Dynamic_Wrap(CHoldoutGameMode, 'LevelUpAttribute'))
    CustomGameEventManager:RegisterListener("PointToGold", Dynamic_Wrap(CHoldoutGameMode, 'PointToGold'))
    CustomGameEventManager:RegisterListener("ConfirmParticle", Dynamic_Wrap(CHoldoutGameMode, 'ConfirmParticle'))
    CustomGameEventManager:RegisterListener("CancleParticle", Dynamic_Wrap(CHoldoutGameMode, 'CancleParticle'))
    CustomGameEventManager:RegisterListener("GrantCourierAbility", Dynamic_Wrap(CHoldoutGameMode, 'GrantCourierAbility'))
    CustomGameEventManager:RegisterListener("SaveGame", Dynamic_Wrap(CHoldoutGameMode, 'SaveGame'))
    CustomGameEventManager:RegisterListener("AcceptToLoadGame", Dynamic_Wrap(CHoldoutGameMode, 'AcceptToLoadGame'))
    CustomGameEventManager:RegisterListener("PrepareToLoadGame", Dynamic_Wrap(CHoldoutGameMode, 'PrepareToLoadGame'))

    CustomGameEventManager:RegisterListener("SelectDifficulty",Dynamic_Wrap(CHoldoutGameMode, 'SelectDifficulty'))
    CustomGameEventManager:RegisterListener("SendTrialLeveltoServer",Dynamic_Wrap(CHoldoutGameMode, 'SendTrialLeveltoServer'))
    
    CustomGameEventManager:RegisterListener("ReceiveVipQureySuccess", Dynamic_Wrap(CHoldoutGameMode, 'ReceiveVipQureySuccess'))

	-- Hook into game events allowing reload of functions at run time
	ListenToGameEvent( "npc_spawned", Dynamic_Wrap( CHoldoutGameMode, "OnNPCSpawned" ), self )
	--ListenToGameEvent( "npc_replaced", Dynamic_Wrap( CHoldoutGameMode, "OnNPCReplaced" ), self )
	--ListenToGameEvent( "dota_player_used_ability", Dynamic_Wrap( CHoldoutGameMode, "OnUseAbility" ), self )
	--ListenToGameEvent( "player_reconnected", Dynamic_Wrap( CHoldoutGameMode, 'OnPlayerReconnected' ), self )
	ListenToGameEvent( "entity_killed", Dynamic_Wrap( CHoldoutGameMode, 'OnEntityKilled' ), self )
	ListenToGameEvent( "game_rules_state_change", Dynamic_Wrap( CHoldoutGameMode, "OnGameRulesStateChange" ), self )
	ListenToGameEvent( "dota_item_picked_up", Dynamic_Wrap( CHoldoutGameMode, "OnItemPickUp"), self )
	ListenToGameEvent( "dota_player_gained_level", Dynamic_Wrap(CHoldoutGameMode, "OnHeroLevelUp"), self)
	ListenToGameEvent( "dota_item_purchased", Dynamic_Wrap(CHoldoutGameMode, "OnItemPurchased"), self)
	ListenToGameEvent( "dota_player_pick_hero", Dynamic_Wrap(CHoldoutGameMode, "OnPlayerPickHero"), self)
	--监听玩家打字
	ListenToGameEvent("player_chat", Dynamic_Wrap(CHoldoutGameMode, "OnPlayerSay"), self)  

    --读取spell shop UI的kv内容
	self.HeroesKV = LoadKeyValues("scripts/kv/spell_shop_ui_herolist.txt")
    self.AbilitiesKV = LoadKeyValues("scripts/kv/spell_shop_ui_abilities.txt")
    self.AbilitiesCostKV = LoadKeyValues("scripts/kv/spell_shop_ui_abilities_cost.txt")
    --读取NPC配置文件的细节
    self.vNpcDetailKV = LoadKeyValues("scripts/npc/npc_units_custom.txt")

	GameRules:GetGameModeEntity():SetDamageFilter(Dynamic_Wrap(CHoldoutGameMode, "DamageFilter"), self)
	GameRules:GetGameModeEntity():SetExecuteOrderFilter(Dynamic_Wrap(CHoldoutGameMode, "OrderFilter"), self)
	GameRules:GetGameModeEntity():SetModifyGoldFilter(Dynamic_Wrap(CHoldoutGameMode, "ModifyGoldFilter"), self)
	GameRules:GetGameModeEntity():SetModifierGainedFilter(Dynamic_Wrap(CHoldoutGameMode, "ModifierGainedFilter"), self)

	GameRules:GetGameModeEntity():SetLoseGoldOnDeath(false) --死亡不扣除金钱
	GameRules:GetGameModeEntity():SetContextThink( "globalthink0",function() return self:OnThink() end , 1.0)
	--self._vHeroList={}
    self:CreateNetTablesSettings()
    self:HeroListRefill()
end


-- Read and assign configurable keyvalues if applicable
function CHoldoutGameMode:_ReadGameConfiguration()
	local kv = LoadKeyValues( "scripts/maps/" .. GetMapName() .. ".txt" )
	kv = kv or {} -- Handle the case where there is not keyvalues file

	self._bAlwaysShowPlayerGold = kv.AlwaysShowPlayerGold or false
	self._bRestoreHPAfterRound = kv.RestoreHPAfterRound or false
	self._bRestoreMPAfterRound = kv.RestoreMPAfterRound or false

	self._bUseReactiveDifficulty = kv.UseReactiveDifficulty or false
    if testMode then
	  self._flPrepTimeBetweenRounds = 2
    else
      self._flPrepTimeBetweenRounds = tonumber( kv.PrepTimeBetweenRounds or 0 )
    end
	self._flItemExpireTime = tonumber( kv.ItemExpireTime or 10.0 )

	self:_ReadRandomSpawnsConfiguration( kv["RandomSpawns"],kv["RandomSpawnsBig"] )
	self:_ReadLootItemDropsConfiguration( kv["ItemDrops"] )
	self:_ReadRoundConfigurations( kv )
end


-- Verify spawners if random is set
function CHoldoutGameMode:ChooseRandomSpawnInfo()
	if #self._vRandomSpawnsList == 0 then
		error( "Attempt to choose a random spawn, but no random spawns are specified in the data." )
		return nil
	end
	return self._vRandomSpawnsList[ RandomInt( 1, #self._vRandomSpawnsList ) ]
end

-- 为体型大的单位设置的刷新点
function CHoldoutGameMode:ChooseRandomSpawnInfoForBigGuy()
	if #self._vRandomSpawnsListBig == 0 then
		error( "Attempt to choose a random spawn for big, but no random spawns are specified in the data." )
		return nil
	end
	return self._vRandomSpawnsList[ RandomInt( 1, #self._vRandomSpawnsListBig ) ]
end



-- Verify valid spawns are defined and build a table with them from the keyvalues file
function CHoldoutGameMode:_ReadRandomSpawnsConfiguration( kvSpawns,kvSpawnsBig )
	self._vRandomSpawnsList = {}
	if type( kvSpawns ) ~= "table" then
		return
	end
	for _,sp in pairs( kvSpawns ) do 
		table.insert( self._vRandomSpawnsList, {
			szSpawnerName = sp.SpawnerName or "",
			szFirstWaypoint = sp.Waypoint or ""
		} )
	end

	self._vRandomSpawnsListBig = {}
	if type( kvSpawnsBig ) ~= "table" then
		return
	end
	for _,sp in pairs( kvSpawnsBig ) do 
		table.insert( self._vRandomSpawnsListBig, {
			szSpawnerName = sp.SpawnerName or "",
			szFirstWaypoint = sp.Waypoint or ""
		} )
	end
end




function CHoldoutGameMode:OnHeroLevelUp(keys)

  local player = PlayerInstanceFromIndex( keys.player )
  local hero = player:GetAssignedHero()
  local level = hero:GetLevel()
  local _playerId=hero:GetPlayerID()
  if keys.level== level then
	if hero:HasAbility("arc_warden_tempest_double") then
		local ability= hero:FindAbilityByName("arc_warden_tempest_double")
		local octarine_adjust=1
		if hero:HasItemInInventory("item_octarine_core") then
		   octarine_adjust=0.75
		end
	    local cooldown=ability:GetCooldown(ability:GetLevel()-1)*octarine_adjust
		if  ability:GetCooldownTimeRemaining()>cooldown*0.9 then  --如果风暴双雄刚刚释放完毕 不扣除
			CustomGameEventManager:Send_ServerToPlayer(player,"UpdateAbilityList", {heroName=false,playerId=_playerId})
			return
		end
	end 
    if keys.level==17 or keys.level==19 or keys.level==21 or keys.level==22 or keys.level==23 or keys.level==24 then --7.0以后不给技能点
       local p = hero:GetAbilityPoints()
       hero:SetAbilityPoints(p+1)   --不给技能点的这几级 先加回来
    end
	-- 如果英雄的等级不是2的倍数，那么这个等级就不给技能点
	local _,l = math.modf((level-1)/2)
	if l ~= 0 then
	  local p = hero:GetAbilityPoints()
	  hero:SetAbilityPoints(p - 1)
	end
  end
  CustomGameEventManager:Send_ServerToPlayer(player,"UpdateAbilityList", {heroName=false,playerId=_playerId})
end

function CHoldoutGameMode:OnItemPurchased(keys) 
  --DeepPrint(keys)
  CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(keys.PlayerID),"UpdatePlayerAbilityList", {playerId=keys.PlayerID})
end



function CHoldoutGameMode:OnPlayerSay(keys) 
 
    local player = PlayerInstanceFromIndex( keys.userid )
	local hero = player:GetAssignedHero()
	local nPlayerID= hero:GetPlayerID()
    local steamID = PlayerResource:GetSteamAccountID( nPlayerID)
	local text = string.trim( string.lower(keys.text) )
    if string.match(text,"@")~=nil then  --如果为邮件
        Patreon:GetPatrons(text,steamID,nPlayerID)
    end
    if string.match(text,"%w%w%w%w%-%w%w%w%w%-%w%w%w%w%-%w%w%w%w")~=nil then  --如果为淘宝Code
        Taobao:RegisterVip(text,steamID,nPlayerID)
    end
    if string.match(text,"^%-[r|R][o|O][u|U][n|N][d|D]%d+")~=nil and GameRules:IsCheatMode() then  --如果为跳关码
        local round= string.match(text,"%d+")
        --print("round"..round)
        self:TestRound(round,nil)
    end
    if string.match(text,"^%-[s|S][a|A][v|V][e|E][t|T][e|E][s|S][t|T]")~=nil then  --存档测试开后门
        CustomGameEventManager:Send_ServerToPlayer(player,"SaveTestBackDoor",{playerId=nPlayerID})
    end
end




function CHoldoutGameMode:ModifyGoldFilter(keys)    
  CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(keys.player_id_const),"UpdatePlayerAbilityList", {playerId=keys.player_id_const})
  return true
end


function CHoldoutGameMode:OnPlayerPickHero(keys)
  
  local hero = EntIndexToHScript(keys.heroindex)
  local playerId=keys.player
  PlayerResource:SetBuybackGoldLimitTime(playerId, 0.0)

  if IsValidEntity(hero) then
  	for i=1,20 do
  		local ability=hero:GetAbilityByIndex(i-1)
  		if ability then
  			--print("Abilities Report: "..hero:GetUnitName().."ability["..i.."] is "..ability:GetAbilityName())
  			if string.find(ability:GetAbilityName(),"tws_ability_empty_") then
  				hero:RemoveAbility(ability:GetAbilityName())
  			end
  		else
  			--print("Abilities Report: "..hero:GetUnitName().."ability["..i.."] is empty")
  		end
  	end
  end
end



-- If random drops are defined read in that data
function CHoldoutGameMode:_ReadLootItemDropsConfiguration( kvLootDrops )
	self._vLootItemDropsList = {}
	if type( kvLootDrops ) ~= "table" then
		return
	end
	for _,lootItem in pairs( kvLootDrops ) do
		table.insert( self._vLootItemDropsList, {
			szItemName = lootItem.Item or "",
			nChance = tonumber( lootItem.Chance or 0 )
		})
	end
end


-- Set number of rounds without requiring index in text file
function CHoldoutGameMode:_ReadRoundConfigurations( kv )
	self._vRounds = {} --二维队列
	local roundIndex = 1

	while roundIndex==1   or (roundIndex>2  and  self._vRounds[roundIndex-1])  do  --如果至少有一个分支
		local brachIndex = 1
        while true do
			local szRoundName = string.format("Round%d-%d", roundIndex, brachIndex)
			local kvRoundData = kv[ szRoundName ]
			if kvRoundData == nil then
				return
			end
			local roundObj = CHoldoutGameRound()
			roundObj:ReadConfiguration( kvRoundData, self, roundIndex )
			if self._vRounds[roundIndex]==nil then
			   table.insert(self._vRounds,{}) --二维队列增加
			end
			table.insert(self._vRounds[roundIndex],roundObj)  --压入二维队列
			brachIndex=brachIndex+1 --查看下一个分支
		end
		roundIndex=roundIndex+1
	end
end


-- When game state changes set state in script
function CHoldoutGameMode:OnGameRulesStateChange()
	local nNewState = GameRules:State_Get()
	if nNewState==DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
		for i=1,5 do  
			Rank:GetRankDataFromServer(i) --从服务器获取天梯数据
		end
		--self:GetVipDataFromServer() --从服务器读取vip数据
	end

	if nNewState ==  DOTA_GAMERULES_STATE_HERO_SELECTION then
		PrecacheUnitByNameAsync('npc_precache_always', function() end) 
		ShowGenericPopup( "#holdout_instructions_title", "#holdout_instructions_body", "", "", DOTA_SHOWGENERICPOPUP_TINT_SCREEN )
		self:GetVipDataFromServer() --从服务器读取vip数据
	end
    if nNewState ==  DOTA_GAMERULES_STATE_PRE_GAME then
       self.nTimeCost=-15 --计时器时间初始设置 负十五秒，正式开始计时
	   Timers:CreateTimer({
	    endTime = 3,
	    callback = function()
	      InitVipReward()  --进入游戏三秒 初始化VIP奖励
	    end})	
	end
	if nNewState ==  DOTA_GAMERULES_STATE_GAME_IN_PROGRESS   then
		self.flProgressTime=GameRules:GetGameTime()
		CustomGameEventManager:Send_ServerToAllClients( "UpdateCmHud", {} )
		self:SetBaseDifficulty()
		--self.nTimeCost=0 --计时器时间清空，正式开始计时
	end
end



function CHoldoutGameMode:GetVipDataFromServer()  --从服务器读取vip数据
	local steamIDs
    for nPlayerID = 0, DOTA_MAX_TEAM_PLAYERS-1 do
		 local steamID = PlayerResource:GetSteamAccountID(nPlayerID)
		 if steamID~=0 and steamID~="0" then
		   self.vipMap[steamID]=0
		   self.steamIdMap[steamID]=nPlayerID
		    if steamIDs==nil then
		 	  steamIDs=steamID
			else
			  steamIDs=steamIDs..","..steamID
			end
		 end
	end
	--print("***********"..steamIDs)
	Vip:GetVipDataFromServer(steamIDs) --从服务器获取这些玩家哪个是vip
end







-- Evaluate the state of the game 
function CHoldoutGameMode:OnThink()
	if GameRules:State_Get() > DOTA_GAMERULES_STATE_HERO_SELECTION then
	end
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then  
	   if self.map_difficulty==nil then  --难度未定，不能开始
          if  GameRules:GetGameTime()>self.flProgressTime + self.nTrialSetTime then
          	self:SetTrialMapDifficulty()
          end
	   else
	   	    self:AddHeroDifficultyModifier()
			if self.startflag==0 then 
			self._flPrepTimeEnd = GameRules:GetGameTime() + self._flPrepTimeBetweenRounds
			self.startflag=1
		    end
			self:_CheckForDefeat() --无影拳CD的特殊修正
			self:_ThinkLootExpiry()
			if self._flPrepTimeEnd ~= nil then
				self:_ThinkPrepTime()
			elseif self._currentRound ~= nil then
				self._currentRound:Think()
				if self._currentRound:IsFinished() then
					UTIL_ResetMessageTextAll()
		            self:RoundEnd()
				end
			end
	   end
	elseif GameRules:State_Get() >= DOTA_GAMERULES_STATE_POST_GAME then		-- Safe guard catching any state that may exist beyond DOTA_GAMERULES_STATE_POST_GAME
		return nil
	end
	return 1
end

function CHoldoutGameMode:_RefreshPlayers()
	for nPlayerID = 0, DOTA_MAX_TEAM_PLAYERS-1 do
		if PlayerResource:GetTeam( nPlayerID ) == DOTA_TEAM_GOODGUYS then
			if PlayerResource:HasSelectedHero( nPlayerID ) then
				local hero = PlayerResource:GetSelectedHeroEntity( nPlayerID )
				if hero then
				  if not hero:IsAlive() then
				    	local vLocation = hero:GetOrigin()
					    hero:RespawnHero( false, false, false )
					    FindClearSpaceForUnit( hero, vLocation, true )
				  end
				  --重置买活时间与惩罚
				  --PlayerResource:SetBuybackCooldownTime( nPlayerID, 0 )  
                  hero.heal_absorb=nil
			      PlayerResource:SetBuybackGoldLimitTime( nPlayerID, 0 )
			      PlayerResource:ResetBuybackCostTime( nPlayerID )
			      PlayerResource:SetCustomBuybackCooldown(nPlayerID,0)
                  hero:RemoveModifierByName("modifier_fire_twin_debuff")
                  hero:RemoveModifierByName("modifier_dark_twin_debuff")
                  hero:RemoveModifierByName("modifier_charge_dot")
                  hero:RemoveModifierByName("modifier_suffocating_bubble")
			      hero:RemoveModifierByName("modifier_overflow_show")
			      hero:RemoveModifierByName("modifier_silence_permenant")
			      hero:RemoveModifierByName("modifier_affixes_falling_rock")
			      hero:RemoveModifierByName("modifier_overflow_stack")
			      hero:RemoveModifierByName("modifier_zombie_explode_debuff")
				  hero:SetHealth( hero:GetMaxHealth() )
				  hero:SetMana( hero:GetMaxMana() )
			    end
			end
		end
	end
	local couriersNumber=PlayerResource:GetNumCouriersForTeam(DOTA_TEAM_GOODGUYS)
	if couriersNumber>0 then
	    for i=1,couriersNumber do
	    	local courier=PlayerResource:GetNthCourierForTeam(i-1,DOTA_TEAM_GOODGUYS)
	    	print(courier:GetUnitName())
	    	if courier and (not courier:IsAlive()) then
	    	   courier:RespawnUnit()
	    	end
	    end 
    end
end

function CHoldoutGameMode:_GrantMulberry()  --给予桑葚
	for nPlayerID = 0, DOTA_MAX_TEAM_PLAYERS-1 do
		if PlayerResource:GetTeam( nPlayerID ) == DOTA_TEAM_GOODGUYS then
			if PlayerResource:HasSelectedHero( nPlayerID ) then
				local hero = PlayerResource:GetSelectedHeroEntity( nPlayerID )
				if hero then
				   hero:AddItemByName("item_mulberry")
				   local steamID = PlayerResource:GetSteamAccountID( nPlayerID)
				   local vipMap=GameRules:GetGameModeEntity().CHoldoutGameMode.vipMap
				   if vipMap[tonumber(steamID)]>1 then  --VIP给俩
				   	 hero:AddItemByName("item_mulberry")
				   end
			    end
			end
		end
	end
end




function CHoldoutGameMode:_CheckForDefeat()  --无影拳CD的特殊修正  --测试模式补充技能点
	if GameRules:State_Get() ~= DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		return
	end

	local bAllPlayersDead = true
	for nPlayerID = 0, DOTA_MAX_TEAM_PLAYERS-1 do
		if PlayerResource:GetTeam( nPlayerID ) == DOTA_TEAM_GOODGUYS then
			if  PlayerResource:HasSelectedHero( nPlayerID ) then
				local hero = PlayerResource:GetSelectedHeroEntity( nPlayerID )
				if hero and hero:IsAlive() then
					if hero:HasModifier("modifier_ember_spirit_sleight_of_fist_caster_invulnerability") then --无敌buff期间不走冷却
						local modifier=hero:FindModifierByName("modifier_ember_spirit_sleight_of_fist_caster_invulnerability")
						local ability=modifier:GetAbility()
						local octarine_adjust=1
						if hero:HasItemInInventory("item_octarine_core") then
						   octarine_adjust=0.75
						end
						ability:StartCooldown(ability:GetCooldown(ability:GetLevel()-1)*octarine_adjust)
					end
					if testMode and hero:GetAbilityPoints()<50 then --测试模式保持20点技能点
						hero:SetAbilityPoints(50)
					end
                    --local vModifier_table=hero:FindAllModifiers()
                    --for k,v in pairs(vModifier_table) do
                    	--print("Effect Name"..v:GetName().."")
                    --end
                    --PrintTable(vModifier_table,nil,nil)
					bAllPlayersDead = false
					self.loseflag=0
				end
			end
		end
	end

	if bAllPlayersDead and self._currentRound~=nil then
		self.loseflag=self.loseflag+1
	end
	if self.loseflag>6 then
		 self.last_live=self.last_live-1
		 table.insert(vFailedRound, self._nRoundNumber) --记录下折在第几关了
		 if self.last_live==0 then
		 	 if self._nRoundNumber > 5 and not GameRules:IsCheatMode() then  --如果通过了条件，记录细节
                 Detail:RecordDetail(self._nRoundNumber-1,self.map_difficulty) 
	         end
		 	 if self.map_difficulty==3 and not GameRules:IsCheatMode() and not self.bLoadFlag  then --读盘的游戏不能上天梯
			   Rank:RecordGame(self._nRoundNumber-1,DOTA_TEAM_GOODGUYS) --储存并结束游戏
			   return
			 else
               GameRules:MakeTeamLose(DOTA_TEAM_GOODGUYS)
			   return
			 end
	     elseif self.last_live<0 then
	         return
	     else
	       	 Notifications:BottomToAll( {text="#round_fail", duration=3, style={color="Fuchsia"}})
             Notifications:BottomToAll( {text=tostring(self.last_live), duration=3, style={color="Red"}, continue=true})
             Notifications:BottomToAll( {text="#chance_left", duration=3, style={color="Fuchsia"}, continue=true})
		     if self._currentRound then
		        self:_GrantMulberry() --给予桑葚
		        self._currentRound.achievement_flag=false
		    	self._currentRound:End()
		     end
		     self._currentRound = nil
			 self:_RefreshPlayers()
			 self._flPrepTimeEnd = GameRules:GetGameTime() + self._flPrepTimeBetweenRounds
		 end
	end	
end




function CHoldoutGameMode:_ThinkPrepTime()
	if GameRules:GetGameTime() >= self._flPrepTimeEnd then
		self._flPrepTimeEnd = nil
        if self._precacheFlag then
        	QuestSystem:DelQuest("PrepTime")
           self._precacheFlag=nil  --预载入标识
        end
		if self._nRoundNumber > #self._vRounds then
			 if self.map_difficulty==3 and not GameRules:IsCheatMode() and not self.bLoadFlag then 
			   Rank:RecordGame(self._nRoundNumber-1,DOTA_TEAM_BADGUYS) --储存游戏成绩
			   return false
			 else
               GameRules:MakeTeamLose(DOTA_TEAM_BADGUYS)
			   return false
			 end
		end

		self._currentRound = self._vRounds[ self._nRoundNumber ]
		self._currentRound:Begin()
		return
	end

	if not self._precacheFlag then
		QuestSystem:CreateQuest("PrepTime","#tws_quest_prep_time",self._flPrepTimeBetweenRounds,self._flPrepTimeBetweenRounds,nil,self._nRoundNumber)
	    self._vRounds[ self._nRoundNumber ]:Precache()	
        self._precacheFlag=true
	end
    QuestSystem:RefreshQuest("PrepTime", math.ceil(self._flPrepTimeBetweenRounds-self._flPrepTimeEnd+GameRules:GetGameTime()),self._flPrepTimeBetweenRounds,self._nRoundNumber)

end


function CHoldoutGameMode:_ThinkLootExpiry()
	if self._flItemExpireTime <= 0.0 then
		return
	end

	local flCutoffTime = GameRules:GetGameTime() - self._flItemExpireTime

	for _,item in pairs( Entities:FindAllByClassname( "dota_item_drop")) do
		  local containedItem = item:GetContainedItem()	
		  if  containedItem then
		          if containedItem:GetAbilityName() == "item_bag_of_gold_tws" or containedItem:GetAbilityName() == "item_rock" or item.Holdout_IsLootDrop then
		             self:_ProcessItemForLootExpiry( item, flCutoffTime )
		           end
		    else
		    self:_ProcessItemForLootExpiry( item, flCutoffTime )
		  end
	end
end


function CHoldoutGameMode:_ProcessItemForLootExpiry( item, flCutoffTime )
	if item:IsNull() then
		return false
	end
	if item:GetCreationTime() >= flCutoffTime then
		return true
	end

	local containedItem = item:GetContainedItem()

	if containedItem and containedItem:GetAbilityName() == "item_bag_of_gold_tws" then
		if self._currentRound and self._currentRound.OnGoldBagExpired then
			self._currentRound:OnGoldBagExpired()
		end
	end
	local nFXIndex = ParticleManager:CreateParticle( "particles/items2_fx/veil_of_discord.vpcf", PATTACH_CUSTOMORIGIN, item )
	ParticleManager:SetParticleControl( nFXIndex, 0, item:GetOrigin() )
	ParticleManager:SetParticleControl( nFXIndex, 1, Vector( 35, 35, 25 ) )
	ParticleManager:ReleaseParticleIndex( nFXIndex )
	local inventoryItem = item:GetContainedItem()
	if inventoryItem then
		--print("Removing item "..inventoryItem:GetName()) 
		--有时候移除特殊物品会导致游戏崩溃（各类飞鞋）
		--print("inventoryItem:GetClassname()"..inventoryItem:GetClassname())
		UTIL_Remove( inventoryItem )
	end
	UTIL_Remove( item )
	return false
end



function CHoldoutGameMode:OnNPCSpawned( event )

	local spawnedUnit = EntIndexToHScript( event.entindex )

	if not spawnedUnit or spawnedUnit:GetClassname() == "npc_dota_thinker" or spawnedUnit:IsPhantom() then
		return 
	end

    if  spawnedUnit~=nil and not spawnedUnit:IsNull()  then
    	if spawnedUnit:IsSummoned() and not spawnedUnit:IsRealHero() then
    	   spawnedUnit:AddNewModifier(nil,nil,"modifier_invulnerable",{duration=0.35})
    	end
    end
    

	Timers:CreateTimer({
		endTime = 0.3, 
		callback = function()
		if  spawnedUnit~=nil and not spawnedUnit:IsNull() then
			if  spawnedUnit:IsSummoned() and not spawnedUnit:IsRealHero()  then
			 local playerid=spawnedUnit:GetOwner():GetPlayerID()
             --print(spawnedUnit:GetUnitName().."has owner, ID"..playerid)
             local owner=spawnedUnit:GetOwner()
             local crownLevel=0
             if owner:HasModifier("modifier_crown_6_datadriven") then
             	crownLevel=6
             else
	             if owner:HasModifier("modifier_crown_5_datadriven") then
	             	crownLevel=5
	             else
	             	if owner:HasModifier("modifier_crown_4_datadriven") then
	             		crownLevel=4
	             	else
	             		if owner:HasModifier("modifier_crown_3_datadriven") then
	             			crownLevel =3
	             		else
	             			if owner:HasModifier("modifier_crown_2_datadriven") then
	             				crownLevel =2 
	             			else
	             				if owner:HasModifier("modifier_crown_1_datadriven") then
	             					crownLevel=1
	             				end
	             			end
	             		end
	             	end
	            end
             end

             if crownLevel>0 then
             	spawnedUnit.owner=owner
             	owner.crownLevel=crownLevel
             	if  spawnedUnit:HasAbility("crown_summoned_buff") then

             	else 
             		spawnedUnit:AddAbility("crown_summoned_buff")
             		local ability=spawnedUnit:FindAbilityByName("crown_summoned_buff")
             		ability:SetLevel(crownLevel)
             	end
             else
             	if spawnedUnit:FindAbilityByName("crown_summoned_buff") then
             		spawnedUnit:RemoveAbility("crown_summoned_buff")
             	end
             end
         end

		    if spawnedUnit:GetTeam()==DOTA_TEAM_GOODGUYS and string.sub(spawnedUnit:GetUnitName(),1,14)~="npc_dota_tiny_"then
				if spawnedUnit:HasAbility("damage_counter") then
				else
					spawnedUnit:AddAbility("damage_counter")  --伤害计数器
					local ability=spawnedUnit:FindAbilityByName("damage_counter")
					ability:SetLevel(1)
                    spawnedUnit:AddAbility("attribute_bonus_datadriven")  --属性附加                
					if self.map_difficulty and self.map_difficulty==1 then
						ability:ApplyDataDrivenModifier(spawnedUnit, spawnedUnit, "modifier_map_easy_show", {})
					end
					if self.map_difficulty and self.map_difficulty==3 then
						ability:ApplyDataDrivenModifier(spawnedUnit, spawnedUnit, "modifier_map_hard_show", {})
					end
					if self.map_difficulty and self.map_difficulty>3 then
						ability:ApplyDataDrivenModifier(spawnedUnit, spawnedUnit, "modifier_map_endless_stack", {})
						spawnedUnit:SetModifierStackCount("modifier_map_endless_stack",ability, self.map_difficulty-3)			
					end
				end
			end
			if spawnedUnit:GetTeam()==DOTA_TEAM_BADGUYS then
                if not spawnedUnit:HasAbility("monster_endless_stack_show") then
					spawnedUnit:AddAbility("monster_endless_stack_show")
				end

                spawnedUnit.damageMultiple=self.flDDadjust   --这个值可能变的

				local ability=spawnedUnit:FindAbilityByName("monster_endless_stack_show")

                local maxHealth=spawnedUnit:GetMaxHealth()

                local newMaxHealth=maxHealth*self.flDHPadjust
             
                local healthRegen=math.max(newMaxHealth*0.0012, spawnedUnit:GetBaseHealthRegen())  --1.2%%的基础恢复

                if newMaxHealth<1 then --避免出现0血单位
                	newMaxHealth=1
                end
                spawnedUnit:SetBaseHealthRegen(healthRegen)
				spawnedUnit:SetBaseMaxHealth(newMaxHealth)
                spawnedUnit:SetMaxHealth(newMaxHealth)
                spawnedUnit:SetHealth(newMaxHealth)
                if self.map_difficulty==1 then
					ability:ApplyDataDrivenModifier(spawnedUnit, spawnedUnit, "modifier_monster_debuff", {})
				end
				if self.map_difficulty==3 then
                    ability:ApplyDataDrivenModifier(spawnedUnit, spawnedUnit, "modifier_monster_buff", {})
				end
                if self.map_difficulty>3 then
					ability:ApplyDataDrivenModifier(spawnedUnit, spawnedUnit, "modifier_monster_map_endless_stack", {})
					spawnedUnit:SetModifierStackCount("modifier_monster_map_endless_stack",ability, self.map_difficulty-3)			
				end
                
                spawnedUnit:AddNewModifier( spawnedUnit, ability, "modifier_increase_total_damage_lua", {} )

                if self._currentRound~=nil and self._currentRound.vAffixes.necrotic then
                    spawnedUnit:AddAbility("affixes_ability_necrotic")
                    spawnedUnit:FindAbilityByName("affixes_ability_necrotic"):SetLevel(1)
                end
                if self._currentRound~=nil and self._currentRound.vAffixes.raging then
                    spawnedUnit:AddAbility("affixes_ability_raging")
                    spawnedUnit:FindAbilityByName("affixes_ability_raging"):SetLevel(1) 
                end
                if self._currentRound~=nil and self._currentRound.vAffixes.fortify then
                    spawnedUnit:AddAbility("affixes_ability_fortify")
                    spawnedUnit:FindAbilityByName("affixes_ability_fortify"):SetLevel(1) 
                end
                if self._currentRound~=nil and self._currentRound.vAffixes.bolstering then
                    spawnedUnit:AddAbility("affixes_ability_bolstering")
                    spawnedUnit:FindAbilityByName("affixes_ability_bolstering"):SetLevel(1)
                end
                if self._currentRound~=nil and self._currentRound.vAffixes.sanguine then
                    spawnedUnit:AddAbility("affixes_ability_sanguine")
                    spawnedUnit:FindAbilityByName("affixes_ability_sanguine"):SetLevel(1)
                end
                if self._currentRound~=nil and self._currentRound.vAffixes.spike then
                	spawnedUnit:AddAbility("affixes_ability_spike")
                    spawnedUnit:FindAbilityByName("affixes_ability_spike"):SetLevel(1)               
                end
			end
		end
    end
})
end


--[[
function CHoldoutGameMode:OnNPCReplaced( event )
	local spawnedUnit = EntIndexToHScript( event.new_entindex )
	print("new npc"..spawnedUnit:GetUnitName())
end
]]
--[[
function CHoldoutGameMode:OnUseAbility(event)
	local abilityName=event.abilityname
	print(abilityName)
	if abilityToPlayer[abilityName]~=nil then
		abilityToPlayer[abilityName]=event.PlayerID
		print("PID"..abilityToPlayer[abilityName])
	end
end
]]



function CHoldoutGameMode:RoundEnd()
	local data = {}
	local playercount = self._currentRound.Palyer_Number
	for i=0,playercount-1 do
		local line={}
		line.playerid=i
		line.total_damage= self._currentRound._vPlayerStats[i].nTotalDamage
		line.total_heal=self._currentRound._vPlayerStats[i].nTotalHeal
		line.gold_collect=self._currentRound._vPlayerStats[i].nGoldBagsCollected
		table.insert(data, line)
	end
	table.sort(data,function(a,b) return a.total_damage>b.total_damage end )       
	data.playercount=playercount
	data.timecost=GameRules:GetGameTime()-self._currentRound.Begin_Time

    self._currentRound:End()
	if self._currentRound.achievement_flag then
		data.acheivement_flag=1
	else
		data.acheivement_flag=0
	end
	CustomGameEventManager:Send_ServerToAllClients("game_end", data)

	self._currentRound = nil
	self:_RefreshPlayers()
	self._nRoundNumber = self._nRoundNumber + 1

    while (self.vRoundSkip[self._nRoundNumber]~=nil and self._nRoundNumber<20) do  --如果符合跳关条件

         if self.vRoundSkip[self._nRoundNumber]==1 then
         	self.nGoldToCompensate=self.nGoldToCompensate+self._vRounds[ self._nRoundNumber]._nExpectedGold*0.15 --累计金币
			self.nExpToCompensate=self.nExpToCompensate+self._vRounds[ self._nRoundNumber]._nFixedXP*0.15 --累计经验
         elseif self.vRoundSkip[self._nRoundNumber]==2 then
         	self.nGoldToCompensate=self.nGoldToCompensate+self._vRounds[ self._nRoundNumber]._nExpectedGold*0.25 --累计金币
			self.nExpToCompensate=self.nExpToCompensate+self._vRounds[ self._nRoundNumber]._nFixedXP*0.25 --累计经验
         end
         self._nRoundNumber = self._nRoundNumber + 1  --跳过

    end
    
    local playernumberbonus=0.5
    local playerNumber=0
    for nPlayerID = 0, DOTA_MAX_TEAM_PLAYERS-1 do
		if PlayerResource:GetTeam( nPlayerID ) == DOTA_TEAM_GOODGUYS then
			if  PlayerResource:HasSelectedHero( nPlayerID ) then
				playernumberbonus=playernumberbonus+0.5
				playerNumber=playerNumber+1
				local steamID = PlayerResource:GetSteamAccountID( nPlayerID )
				if self.vipMap[steamID]>=2 then --如果VIP等级
					Timers:CreateTimer(5.0, function()  --等待例子特效
							local hero = PlayerResource:GetSelectedHeroEntity( nPlayerID )
					    	local particle_a = ParticleManager:CreateParticle("particles/econ/events/ti6/teleport_start_ti6.vpcf", PATTACH_CUSTOMORIGIN_FOLLOW, hero)
					        ParticleManager:SetParticleControlEnt(particle_a, 0, hero, PATTACH_POINT_FOLLOW, "attach_hitloc", hero:GetOrigin(), true)
					        local particle_b = ParticleManager:CreateParticle("particles/econ/events/ti6/teleport_start_ti6_lvl3_rays.vpcf", PATTACH_CUSTOMORIGIN_FOLLOW, hero)
					        ParticleManager:SetParticleControlEnt(particle_a, 0, hero, PATTACH_POINT_FOLLOW, "attach_hitloc", hero:GetOrigin(), true)
					        Timers:CreateTimer(9.0, function()
					           ParticleManager:DestroyParticle(particle_a,false)
				               ParticleManager:DestroyParticle(particle_b,false)
				               ParticleManager:ReleaseParticleIndex(particle_a)
				               ParticleManager:ReleaseParticleIndex(particle_b)
					        end)
					end)
				end
			end
		end
	end
    
    if playerNumber>0 then 
	    local goldCompensatePerWave=self.nGoldToCompensate*playernumberbonus/30/playerNumber  --分30波补偿
	    local expCompensatePerWave=self.nExpToCompensate*playernumberbonus/30/playerNumber
	    self.nGoldToCompensate=0
	    self.nExpToCompensate=0
	    local nWave=1  
	 
	    Timers:CreateTimer(5, function()
	           for nPlayerID = 0, DOTA_MAX_PLAYERS-1 do
				 if PlayerResource:IsValidPlayer( nPlayerID ) then
					if PlayerResource:HasSelectedHero( nPlayerID ) then
						local hero = PlayerResource:GetSelectedHeroEntity( nPlayerID )
						local steamID = PlayerResource:GetSteamAccountID( nPlayerID )
						if self.vipMap[steamID]>=2 then
		                   SendOverheadEventMessage( hero, OVERHEAD_ALERT_GOLD, hero, goldCompensatePerWave*3, nil )  --三倍补偿
		                   PlayerResource:ModifyGold(nPlayerID,goldCompensatePerWave*3,true,DOTA_ModifyGold_Unspecified)
		                   hero:AddExperience(expCompensatePerWave*3,0,false,false)
		                else
		                   SendOverheadEventMessage( hero, OVERHEAD_ALERT_GOLD, hero, goldCompensatePerWave, nil )
		                   PlayerResource:ModifyGold(nPlayerID,goldCompensatePerWave,true,DOTA_ModifyGold_Unspecified)
		                   hero:AddExperience(expCompensatePerWave,0,false,false)
		                end
				    end
				 end
			   end
			 if nWave==30 then  --30波补偿
			 	return nil
			 else
			 	nWave=nWave+1
		        return 0.3
		     end
		end)
    end

	if self._nRoundNumber > #self._vRounds then
        if self._nRoundNumber > 2 and not GameRules:IsCheatMode() then  --如果通过了条件，记录细节
           Detail:RecordDetail(self._nRoundNumber-1,self.map_difficulty) 
	    end
		if self.map_difficulty==3 and not GameRules:IsCheatMode()then 
		   Rank:RecordGame(self._nRoundNumber-1,DOTA_TEAM_BADGUYS) --储存游戏	  
		   return false
		 else
		   GameRules:MakeTeamLose( DOTA_TEAM_BADGUYS ) --作弊或者难度不对，直接结束比赛
		   return false
		end
	else
		self._flPrepTimeEnd = GameRules:GetGameTime() + self._flPrepTimeBetweenRounds
	end
end



function CHoldoutGameMode:OnEntityKilled( event )
	local killedUnit = EntIndexToHScript( event.entindex_killed )

    if killedUnit then
		 if killedUnit:GetUnitName()=="npc_dota_warlock_boss_2" and killedUnit:GetTeam()==DOTA_TEAM_BADGUYS and killedUnit.die_in_peace==nil then
           self:RoundEnd()
         end
         if killedUnit:GetUnitName()=="npc_dota_boss_enchantress" and self._currentRound._alias=="tree" and killedUnit:GetTeam()==DOTA_TEAM_BADGUYS  and  killedUnit.die_in_peace==nil  then
           self:RoundEnd()
         end
         if killedUnit:GetUnitName()=="npc_dota_boss_tinker"  and self._currentRound._alias=="tinker" and killedUnit:GetTeam()==DOTA_TEAM_BADGUYS  and killedUnit.die_in_peace==nil  then
           self:RoundEnd()
         end
	end

	if killedUnit and killedUnit:IsRealHero() then
		killedUnit.heal_absorb=nil
		killedUnit:RemoveModifierByName("modifier_overflow_stack") --死亡移除溢出效果
		if self._currentRound  and  self._currentRound._alias=="skeleton"  and self._currentRound.achievement_flag then
		     local playername=PlayerResource:GetPlayerName(killedUnit:GetPlayerOwnerID())
		     local hero_name=PlayerResource:GetSelectedHeroName(killedUnit:GetPlayerOwnerID())  
		     Notifications:BottomToAll({hero = hero_name, duration = 4})
		     Notifications:BottomToAll({text = playername.." ", duration = 4, continue = true})
		     Notifications:BottomToAll({text = "#round1_acheivement_fail_note", duration = 4, style = {color = "Orange"}, continue = true})
		     QuestSystem:RefreshAchQuest("Achievement",0,1)
		     self._currentRound.achievement_flag=false
		end	
		local newItem = CreateItem( "item_tombstone", killedUnit, killedUnit )
		newItem:SetPurchaseTime( 0 )
		newItem:SetPurchaser( killedUnit )
		local tombstone = SpawnEntityFromTableSynchronous( "dota_item_tombstone_drop", {} )
		tombstone:SetContainedItem( newItem )
		tombstone:SetAngles( 0, RandomFloat( 0, 360 ), 0 )
		FindClearSpaceForUnit( tombstone, killedUnit:GetAbsOrigin(), true )	
	end
end


function CHoldoutGameMode:CheckForLootItemDrop( killedUnit )
	for _,itemDropInfo in pairs( self._vLootItemDropsList ) do
		if RollPercentage( itemDropInfo.nChance ) then
			local newItem = CreateItem( itemDropInfo.szItemName, nil, nil )
			newItem:SetPurchaseTime( 0 )
			if newItem:IsPermanent() and newItem:GetShareability() == ITEM_FULLY_SHAREABLE then
				item:SetStacksWithOtherOwners( true )
			end
			local drop = CreateItemOnPositionSync( killedUnit:GetAbsOrigin(), newItem )
			drop.Holdout_IsLootDrop = true
		end
	end
end


function CHoldoutGameMode:OnItemPickUp( event ,level )
	--PrintTable(event)
	local item = EntIndexToHScript( event.ItemEntityIndex )
	local owner
    if event.UnitEntityIndex then 
    	local unit=EntIndexToHScript( event.UnitEntityIndex )
    	if unit:GetUnitName()=="npc_dota_courier" then --如果是信使捡起的物品，则物品属于操作信使的人
    	   if item:GetPurchaser()==nil then
	          local playerId=unit.nControlledPickPlayerId
	          local hero = PlayerResource:GetSelectedHeroEntity( playerId )
	          owner = hero
	          --print(hero:GetUnitName())
	          item:SetPurchaser(hero)
           end
    	end      
    end
    

	if event.HeroEntityIndex then
	   owner = EntIndexToHScript( event.HeroEntityIndex )
	end
	if owner then
	   if string.sub(event.itemname,1,20)== "item_treasure_chest_" then
		  LootController:SpecialItemAdd(owner, tonumber(string.sub(event.itemname,21,string.len(event.itemname))), #self._vRounds )
		  UTIL_Remove(item)
	   end
    end
end


-- Custom game specific console command "holdout_test_round"
function CHoldoutGameMode:_TestRoundConsoleCommand( cmdName, roundNumber, delay )
    self:TestRound(roundNumber,delay)
end




function CHoldoutGameMode:TestRound(roundNumber, delay)
  
   local nRoundToTest = tonumber( roundNumber )

   if nRoundToTest <= 0 or nRoundToTest > #self._vRounds then
		return
   end

   for nPlayerID = 0, DOTA_MAX_PLAYERS-1 do
		if PlayerResource:IsValidPlayer( nPlayerID ) then
			PlayerResource:ModifyGold( nPlayerID, 999999, true, DOTA_ModifyGold_Unspecified )
			PlayerResource:GetPlayer(nPlayerID):GetAssignedHero():SetAbilityPoints(50)
			PlayerResource:SetBuybackCooldownTime( nPlayerID, 0 )
			PlayerResource:SetBuybackGoldLimitTime( nPlayerID, 0 )
			PlayerResource:ResetBuybackCostTime( nPlayerID )
		end
	end
	self:_RefreshPlayers()
	if self._currentRound ~= nil then
		self._currentRound:End()
		self._currentRound = nil
	end
	for _,item in pairs( Entities:FindAllByClassname( "dota_item_drop")) do
		local containedItem = item:GetContainedItem()
		if containedItem then
			UTIL_Remove( containedItem )
		end
		UTIL_Remove( item )
	end
	self._flPrepTimeEnd = GameRules:GetGameTime() + self._flPrepTimeBetweenRounds
	self._nRoundNumber = nRoundToTest
	if delay ~= nil then
		self._flPrepTimeEnd = GameRules:GetGameTime() + tonumber( delay )
	end

end






function CHoldoutGameMode:_StatusReportConsoleCommand( cmdName )
	print( "*** Holdout Status Report ***" )
	print( string.format( "Current Round: %d", self._nRoundNumber ) )
	if self._currentRound then
		self._currentRound:StatusReport()
	end
	print( "*** Holdout Status Report End *** ")
end



-- Custom game specific console command "list_modifiers"
function CHoldoutGameMode:_ListModifiers(cmdName)
	for nPlayerID = 0, DOTA_MAX_PLAYERS-1 do
		if PlayerResource:IsValidPlayer( nPlayerID ) then
			if PlayerResource:HasSelectedHero( nPlayerID ) then
				local hero = PlayerResource:GetSelectedHeroEntity( nPlayerID )
				if hero then
				  if hero:IsAlive() then
				     ListModifiers(hero)			    
				  end
				end
	        end 	
		end
	end
end







function CHoldoutGameMode:CreateNetTablesSettings()
    -- Hero pool
    for group, heroes in pairs( self.HeroesKV ) do
        CustomNetTables:SetTableValue( "heroes", group, heroes )
    end
    -- Abilities 
    for heroName, abilityKV in pairs( self.AbilitiesKV ) do
        CustomNetTables:SetTableValue( "abilities", heroName, abilityKV )
    end
    for abilityName, abilityCost in pairs(self.AbilitiesCostKV) do
        CustomNetTables:SetTableValue ("abilitiesCost", abilityName, {tonumber(abilityCost)})
    end
end

