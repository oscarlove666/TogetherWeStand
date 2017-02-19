--damageTable.damagetype_const
--1 physical
--2 magical
--4 pure

sp_exempt_table = {}
sp_exempt_table["necrolyte_reapers_scythe_datadriven"]=true
sp_exempt_table["huskar_life_break"]=true
sp_exempt_table["self_huskar_life_break"]=true
sp_exempt_table["zuus_static_field"]=true
sp_exempt_table["death_prophet_spirit_siphon"]=true
sp_exempt_table["elder_titan_earth_splitter"]=true
sp_exempt_table["winter_wyvern_arctic_burn"]=true
sp_exempt_table["doom_bringer_infernal_blade"]=true
sp_exempt_table["phoenix_sun_ray"]=true
sp_exempt_table["abyssal_underlord_firestorm"]=true


function CHoldoutGameMode:DamageFilter(damageTable)

   --DeepPrint( damageTable )
   if damageTable and damageTable.entindex_attacker_const then
	  local attacker = EntIndexToHScript(damageTable.entindex_attacker_const)
	  local victim = EntIndexToHScript(damageTable.entindex_victim_const)
	  if  attacker and attacker:GetTeam()==DOTA_TEAM_GOODGUYS then
	        if damageTable.entindex_inflictor_const ~=nil then --有明确来源技能
	           local ability=EntIndexToHScript(damageTable.entindex_inflictor_const)
             --print("Ability Name: "..ability:GetAbilityName().." Attacker: "..attacker:GetUnitName() )
	           if attacker.sp~=nil and  damageTable.damagetype_const==2  and  not sp_exempt_table[ability:GetAbilityName()]  then
	           	 if ability:IsToggle() or ability:IsPassive() then
	              damageTable.damage=damageTable.damage*(1+attacker.sp*0.3*attacker:GetIntellect()/100)  
	             else
	              damageTable.damage=damageTable.damage*(1+attacker.sp*attacker:GetIntellect()/100)
	             end
	           end
	        else
	           if attacker.sp~=nil and  damageTable.damagetype_const==2 then --无明确来源技能
	             damageTable.damage=damageTable.damage*(1+attacker.sp*attacker:GetIntellect()/100) 
	           end
	        end

        	local playerid=nil
        	if attacker:GetOwner() then
             if attacker:GetOwner():IsPlayer() then
        		   playerid=attacker:GetOwner():GetPlayerID()
             end
        	end
        	if playerid==nil then
        		 --print(attacker:GetUnitName().."has no owner")
        	end
        	if self._currentRound and playerid then
        		self._currentRound._vPlayerStats[playerid].nTotalDamage=self._currentRound._vPlayerStats[playerid].nTotalDamage+damageTable.damage
        	end
          if victim and victim:HasModifier("modifier_affixes_spike") then  --处理尖刺技能
               local damage_table = {}
               damage_table.attacker = victim
               damage_table.victim = attacker
               damage_table.damage_type = DAMAGE_TYPE_PURE
               damage_table.ability = victim:FindAbilityByName("affixes_ability_spike")
               damage_table.damage = damageTable.damage
               damage_table.damage_flags = DOTA_DAMAGE_FLAG_NONE
               ApplyDamage(damage_table)
          end
          if victim and victim:HasModifier("modifier_share_damage_passive") then  --处理伤害共享技能
              local allies = FindUnitsInRadius(DOTA_TEAM_BADGUYS, Vector(0,0,0), nil, -1, DOTA_UNIT_TARGET_TEAM_FRIENDLY, DOTA_UNIT_TARGET_ALL, DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES, 0, false )
              for _,ally in pairs(allies) do  --共享伤害 不再伤害本体 
                  if ally:HasAbility("share_damage_passive") and ally~=victim  then             
                    local damage_table = {}
                    damage_table.attacker = victim
                    damage_table.victim = ally
                    damage_table.damage_type = DAMAGE_TYPE_PURE
                    damage_table.ability = victim:FindAbilityByName("share_damage_passive")
                    damage_table.damage = damageTable.damage
                    damage_table.damage_flags = DOTA_DAMAGE_FLAG_NONE
                    ApplyDamage(damage_table)
                  end
              end 
          end
    end
    if attacker:GetTeam()==DOTA_TEAM_BADGUYS then

        --处理窒息气泡 原始伤害
        if victim:HasModifier("modifier_share_damage_passive")  then      
            if damageTable.entindex_inflictor_const ~=nil then --有明确技能伤害来源
              local ability=EntIndexToHScript(damageTable.entindex_inflictor_const) --如果技能为潮汐的两个伤害技能
              if (ability:GetAbilityName()=="boss_current_storm" or ability:GetAbilityName()=="boss_greate_gush") and victim.suffocating_bubble_take~=nil and victim.suffocating_bubble_take >0 then
                  victim.suffocating_bubble_take=victim.suffocating_bubble_take-damageTable.damage 
                  if victim.suffocating_bubble_take <0 then
                     victim.RemoveModifierByName("modifier_share_damage_passive")
                     victim.suffocating_bubble_take=nil                    
                  end
                  return false
              end
            end
        end

        if damageTable.damagetype_const ~=1 and attacker.damageMultiple~=nil then  --Ability damage
          damageTable.damage=damageTable.damage*attacker.damageMultiple
        end
      	if attacker:HasModifier("modifier_night_damage_stack") then
      		local ability=attacker:FindAbilityByName("night_creature_increase_damage")
      		local magic_enhance_per_stack=ability:GetSpecialValueFor("magic_enhance_per_stack")
      		local stacks_number=attacker:GetModifierStackCount("modifier_night_damage_stack",ability)
      		if damageTable.damagetype_const==2 or damageTable.damagetype_const==4  then
      			damageTable.damage=damageTable.damage* (1+stacks_number*magic_enhance_per_stack)
      		end     	
      	end
        -- 受伤害龙心进入CD
        if victim:HasItemInInventory("item_heart") or victim:HasItemInInventory("item_heart_2")  then
            for i=0,5 do
              local itemAbility=victim:GetItemInSlot(i)
              if itemAbility~=nil then
                  if itemAbility:GetAbilityName()=="item_heart" or itemAbility:GetAbilityName()=="item_heart_2" then
                     local heartCooldown=itemAbility:GetCooldown(1)
                     itemAbility:StartCooldown(heartCooldown)
                  end
              end
            end
        end
     end
   end
   return true
end
