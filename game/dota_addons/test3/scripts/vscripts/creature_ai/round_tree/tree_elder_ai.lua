--[[
猛犸BOSS的AI
]]


require( "ai_core" )
require("addon_game_mode")

behaviorSystem = {} -- create the global so we can assign to it

function Spawn( entityKeyValues )
	if  thisEntity:GetTeam()==DOTA_TEAM_BADGUYS then
	  thisEntity:SetContextThink( "AIThink", AIThink, 0.25 )
      behaviorSystem = AICore:CreateBehaviorSystem( { BehaviorNone , BehaviorThrowHook , BehaviorPlasma_Field , BehaviorStrike , BehaviorFreeze} )
    end
end

function AIThink() -- For some reason AddThinkToEnt doesn't accept member functions
       return behaviorSystem:Think()
end
--------------------------------------------------------------------------------------------------------
BehaviorNone = {}
function BehaviorNone:Evaluate()
	return 2 -- must return a value > 0, so we have a default 控制大方向，往一个最近的英雄处靠近
end

function BehaviorNone:Begin()
	self.endTime = GameRules:GetGameTime() + 1
	self.target=nil
	local allEnemies = FindUnitsInRadius( DOTA_TEAM_BADGUYS, thisEntity:GetOrigin(), nil, -1, DOTA_UNIT_TARGET_TEAM_ENEMY, DOTA_UNIT_TARGET_HERO, DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES, FIND_CLOSEST, false )
		if #allEnemies > 0 then
			self.target = allEnemies[1]
		end


	if self.target then
		self.order =
		{
			UnitIndex = thisEntity:entindex(),
			OrderType = DOTA_UNIT_ORDER_ATTACK_MOVE,
			Position =  self.target:GetOrigin()
		}
	else
		self.order =
		{
			UnitIndex = thisEntity:entindex(),
			OrderType = DOTA_UNIT_ORDER_STOP
		}
	end
end

 BehaviorNone.Continue=BehaviorNone.Begin
--------------------------------------------------------------------------------------------------------
BehaviorPlasma_Field = {}

function BehaviorPlasma_Field:Evaluate()    --疯狂成长
	local desire = 0

	-- let's not choose this twice in a row
	if currentBehavior == self then return desire end

	self.plasmaAbility = thisEntity:FindAbilityByName( "elder_tree_overgrowth" )

	if self.plasmaAbility and self.plasmaAbility:IsFullyCastable() then
		self.target = AICore:RandomEnemyHeroInRange( thisEntity, 550)
		if self.target then
			desire = 7
		end
	end
	return desire
end

function BehaviorPlasma_Field:Begin()
	self.endTime = GameRules:GetGameTime() + 1
	self.order =
	{
		UnitIndex = thisEntity:entindex(),
		OrderType = DOTA_UNIT_ORDER_CAST_NO_TARGET,
		AbilityIndex = self.plasmaAbility:entindex()
	}

end
BehaviorPlasma_Field.Continue = BehaviorPlasma_Field.Begin
--------------------------------------------------------------------------------------------------------
AICore.possibleBehaviors = {BehaviorNone ,BehaviorPlasma_Field}

