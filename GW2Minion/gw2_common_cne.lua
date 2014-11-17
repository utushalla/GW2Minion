gw2_common_cne = {}


-- Handle Death by waiting for rezz & respawn at nearest Waypoint
c_Dead = inheritsFrom( ml_cause )
e_Dead = inheritsFrom( ml_effect )
c_Dead.lastHealth = nil
c_Dead.deadTmr = 0
function c_Dead:evaluate()
	if ( ml_global_information.Player_Alive == false ) then
		return true
	end
	c_Dead.deadTmr = 0
	return false
end
function e_Dead:execute()
	ml_log("e_Dead")
	-- check for partymember who can raise us
	local party = ml_global_information.Player_Party
	local found = false	
	if ( TableSize(party) > 1 ) then		
		local idx,pmember = next(party)	
		while (idx and pmember) do
			if ( pmember.id ~= 0 ) then
				local char = CharacterList:Get(pmember.id)
				if ( char ) then
					local cPos = char.pos
					if ( cPos and Distance2D ( ml_global_information.Player_Position.x, ml_global_information.Player_Position.y, cPos.x, cPos.y) < 4000 and char.dead == false) then
						found = true
						break
					end
				end
			end
			idx,pmember=next(party,idx)
		end
	end	
	-- Check for nearby Players who can rezz us
	if ( found == false ) then
		if ( TableSize(CharacterList("nearest,alive,friendly,player,maxdistance=1200"))>0 ) then
			found = true
		end
	end
	
		if ( ( not found and TimeSince(c_Dead.deadTmr) > 5000) or TimeSince(c_Dead.deadTmr) > 30000 ) then -- wait a bit longer for other ppl to rezz us if they are around
			
			if ( c_Dead.deadTmr == 0 or c_Dead.lastHealth == nil or c_Dead.lastHealth < ml_global_information.Player_Health.current ) then
				c_Dead.lastHealth = ml_global_information.Player_Health.current
				c_Dead.deadTmr = ml_global_information.Now

				if (c_Dead.lastHealth ~= 0) then
					c_Dead.deadTmr = ml_global_information.Now + 10000
				end
				ml_log( "Dead: We are beeing revived...waiting a bit longer " )
				
			elseif ( c_Dead.deadTmr ~= 0 and c_Dead.lastHealth ~= nil ) then
				c_Dead.lastHealth = nil
				c_Dead.deadTmr = 0
				d( "Dead: RESPAWN AT NEAREST WAYPOINT " )
				d( Player:RespawnAtClosestWaypoint() )
				ml_global_information.Stop()
				ml_global_information.Reset() -- clear queues here ?
			end
		end
end


-- Handle Downed state, heal and attack nearby aggro targets
c_Downed = inheritsFrom( ml_cause )
e_Downed = inheritsFrom( ml_effect )
function c_Downed:evaluate()
	return Player.healthstate == GW2.HEALTHSTATE.Downed
end
function e_Downed:execute()
	ml_log("e_Downed")
	
	if ( ml_global_information.Player_IsMoving ) then Player:StopMovement() end 
	
	if ( Player:IsSpellOnCooldown( GW2.SKILLBARSLOT.Slot_4 ) ) then
		-- Try to Fight
		local TList = ( CharacterList("lowesthealth,attackable,aggro,alive,los,maxdistance="..ml_global_information.AttackRange) )
		
		if ( TableSize( TList ) == 0 ) then
			TList = ( GadgetList("attackable,alive,aggro,los,maxdistance="..ml_global_information.AttackRange) )
		end
		
		if ( TableSize( TList ) > 0 ) then
			local id, E  = next( TList )
			if ( id ~= nil and id ~= 0 and E ~= nil ) then
				
				local target = Player:GetTarget()
				if ( not target or target.id ~= id ) then
					Player:SetTarget(id)
					return ml_log(true)				
				else
					return ml_log(gw2_skill_manager.Attack( target ))
				end			
			end
		end
		
	else 
		-- Heal
		if ( Player.castinfo.duration == 0 ) then
			Player:CastSpell( GW2.SKILLBARSLOT.Slot_4 )
			ml_global_information.Wait(500)
		end
	end	
end


c_RezzPartyMember = inheritsFrom( ml_cause )
e_RezzPartyMember = inheritsFrom( ml_effect )
e_RezzPartyMember.target = nil
function c_RezzPartyMember:evaluate()
	local party = ml_global_information.Player_Party
	if ( TableSize(party) >0 ) then
		local idx,pmember = next(party)	
		while (idx and pmember) do
			if ( pmember.id ~= 0 ) then
				local char = CharacterList:Get(pmember.id)
				if ( char ) then
					if ( char.onmesh and (char.downed == true or char.dead == true) and ml_global_information.Player_Health.percent > 50 and char.pathdistance < 4000) then
						e_RezzPartyMember.target = char
						return true
					end
				end
			end
			idx,pmember=next(party,idx)
		end
	end
	e_RezzPartyMember.target = nil
	return false
end
function e_RezzPartyMember:execute()
	ml_log("e_RezzPartyMember")	
	
	if ( e_RezzPartyMember.target ) then
		if (not e_RezzPartyMember.target.isInInteractRange) then
			-- MoveIntoInteractRange
			local tPos = e_RezzPartyMember.target.pos
			if ( tPos ) then
				
				local newTask = gw2_task_moveto.Create()
				newTask.targetPos = tPos
				newTask.targetID = e_RezzPartyMember.target.id
				newTask.targetType = "character"
				newTask.name = "MoveTo Revive PartyMember"
				ml_task_hub:CurrentTask():AddSubTask(newTask)					
				ml_log("MoveToDownedPartyMember..")
				return ml_log(true)
			end
		else
			-- Grab that thing
			if ( ml_global_information.Player_IsMoving == true ) then Player:StopMovement() end 
			
			if (Player.profession == 8 ) then -- Necro, leave shroud
				local deathshroud = Player:GetSpellInfo(GW2.SKILLBARSLOT.Slot_13)
				if ( deathshroud ~= nil and deathshroud.skillID == 10585 and Player:CanCast() and Player:GetCurrentlyCastedSpell() == 17) then
					Player:CastSpell(GW2.SKILLBARSLOT.Slot_13)
					ml_global_information.Wait(500)
					return
				end
			end
					
			local t = Player:GetTarget()
			if ( not t or t.id ~= e_RezzPartyMember.target.id ) then
				Player:SetTarget( e_RezzPartyMember.target.id )
			else		
				ml_log("Rezzing PartyMember..")
				Player:Interact( e_RezzPartyMember.target.id )
				ml_global_information.Wait(1000)
				return ml_log(true)
			end
		end
		
	else	
		ml_error("There should be a downed/dead partymember but we cant find him!")
	end
end
-- used for example in task_grind Overwatch when running a subtask moveto which brings the player to the target that should be rezzed
c_RezzOverWatchCheck = inheritsFrom( ml_cause )
e_RezzOverWatchCheck = inheritsFrom( ml_effect )
function c_RezzOverWatchCheck:evaluate()
	if ( ml_task_hub:CurrentTask() ~= nil and ( ml_task_hub:CurrentTask().name == "MoveTo Revive NPC" or ml_task_hub:CurrentTask().name == "MoveTo Revive Downed Player" or ml_task_hub:CurrentTask().name == "MoveTo Revive PartyMember") and ml_task_hub:CurrentTask().targetPos ~= nil and ml_task_hub:CurrentTask().targetID ~= nil ) then
		local character = CharacterList:Get(ml_task_hub:CurrentTask().targetID)
		if ( character ~= nil and character.alive) then
			return true
		end
	end
	return false
end
function e_RezzOverWatchCheck:execute()
	-- the subtask moveto should be automatically be deleted once we are here, so we do nothing..
	ml_log("e_RezzOverWatchCheck")
end

c_reviveDownedPlayersInCombat = inheritsFrom( ml_cause )
e_reviveDownedPlayersInCombat = inheritsFrom( ml_effect )
e_reviveDownedPlayersInCombat.target = nil
function c_reviveDownedPlayersInCombat:evaluate()
	if ( gRevivePlayers == "1" and ml_global_information.Player_Health.percent > 50 ) then
		local CList = CharacterList("shortestpath,selectable,interactable,downed,friendly,player,onmesh,maxdistance=2000")
		if ( TableSize( CList ) > 0 ) then 
			local id,entity = next (CList)
			if ( id and entity ) then
				e_reviveDownedPlayersInCombat.target = entity
				return true
			end
		end
	end
	e_reviveDownedPlayersInCombat.target = nil
	return false
end
function e_reviveDownedPlayersInCombat:execute()
	ml_log("e_reviveDownedPlayersInCombat")
	if ( e_reviveDownedPlayersInCombat.target ) then
			
		if (not e_reviveDownedPlayersInCombat.target.isInInteractRange) then
			-- MoveIntoInteractRange
			local tPos = e_reviveDownedPlayersInCombat.target.pos
			if ( tPos ) then
				
				local newTask = gw2_task_moveto.Create()
				newTask.targetPos = tPos
				newTask.targetID = e_reviveDownedPlayersInCombat.target.id
				newTask.targetType = "character"
				newTask.name = "MoveTo Revive Downed Player" -- giving it a special name so the overwatch knows when to kick in 
				ml_task_hub:CurrentTask():AddSubTask(newTask)					
				ml_log("MoveToDownedPartyMember..")
				return ml_log(true)
			end
		else
			-- Grab that thing
			if ( ml_global_information.Player_IsMoving ) then Player:StopMovement() end
			
			local t = Player:GetTarget()
			if ( not t or t.id ~= e_reviveDownedPlayersInCombat.target.id ) then
				Player:SetTarget( e_reviveDownedPlayersInCombat.target.id )
			else
				
				-- yeah I know, but this usually doesnt break ;)											
				if ( Player.profession == 8 ) then
					local skill = Player:GetSpellInfo(GW2.SKILLBARSLOT.Slot_1)
					if ( skill ~= nil ) then
						if ( skill.skillID == 10554 ) then
							Player:CastSpell(GW2.SKILLBARSLOT.Slot_13) -- Leave Death Shroud
							return
						-- add more here if needed
						end
					end
				end
				ml_log("Reviving..")
				Player:Interact( e_reviveDownedPlayersInCombat.target.id )
				ml_global_information.Wait(1000)
				return true						
			end
		end
	end
	return ml_log(false)	
end

------------
c_reviveNPC = inheritsFrom( ml_cause )
e_reviveNPC = inheritsFrom( ml_effect )
function c_reviveNPC:evaluate()
    return (gRevive == "1" and not ml_global_information.Player_InCombat and ml_global_information.Player_Health.percent > 75 and TableSize(CharacterList("nearest,selectable,interactable,dead,friendly,npc,onmesh,maxdistance=2000,exclude="..ml_blacklist.GetExcludeString(GetString("monsters")))) > 0)
end
function e_reviveNPC:execute()
	ml_log("ReviveNPC ")
	
	if ( Player.castinfo.duration ~= 0 ) then
		ml_log("Reviving NPC...")
		return ml_log(true)
	end
				
	local CList = CharacterList("shortestpath,selectable,interactable,dead,friendly,npc,onmesh,maxdistance=2500,exclude="..ml_blacklist.GetExcludeString(GetString("monsters")))
	if ( TableSize(CList) > 0 ) then
		local id,target = next(CList)
		if ( id and target ) then
			if ( not target.isInInteractRange ) then
				
				Player:StopMovement()
				local newTask = gw2_task_moveto.Create()
				newTask.name = "MoveTo Revive NPC" -- giving it a special name so the overwatch knows when to kick in 
				newTask.targetPos = target.pos
				ml_task_hub:CurrentTask():AddSubTask(newTask)			
				return ml_log(true)
				
			else
				gw2_common_functions.NecroLeaveDeathshroud()
				if ( Player.castinfo.duration == 0 ) then
					ml_log("Starting to Revive NPC...")
					Player:Interact(target)
					ml_global_information.Wait(1000)
					
				end
				return ml_log(true)
			end
			
		end
	end
	return ml_log(false)
end


-- Range limited to Attackrange 
c_AttackBestNearbyCharacterTarget = inheritsFrom( ml_cause )
e_AttackBestNearbyCharacterTarget = inheritsFrom( ml_effect )
c_AttackBestNearbyCharacterTarget.target = nil
function c_AttackBestNearbyCharacterTarget:evaluate()
	c_AttackBestNearbyCharacterTarget.target = gw2_common_functions.GetBestCharacterTargetForAssist()
	if ( c_AttackBestNearbyCharacterTarget.target ~= nil ) then
		return true
	end
	c_AttackBestNearbyCharacterTarget.target = nil
	return false
end
function e_AttackBestNearbyCharacterTarget:execute()
	ml_log( "AttackBestCharacterTarget" )
	gw2_skill_manager.Attack( c_AttackBestNearbyCharacterTarget.target )	
	c_AttackBestNearbyCharacterTarget.target = nil
end

--
c_FightAggro = inheritsFrom( ml_cause )
e_FightAggro = inheritsFrom( ml_effect )
c_FightAggro.target = nil
function c_FightAggro:evaluate()
	local target = gw2_common_functions.GetBestAggroTarget()
	if ( target ) then
		c_FightAggro.target = target
		return ml_global_information.Player_SwimState == GW2.SWIMSTATE.NotInWater and c_FightAggro.target ~= nil			
	end
	
	c_FightAggro.target = nil
	return false
end
function e_FightAggro:execute()
	ml_log("e_FightAggro ")
			
	if (c_FightAggro.target ~= nil) then
		Player:StopMovement()
		local newTask = gw2_task_combat.Create()
		newTask.targetID = c_FightAggro.target.id		
		newTask.targetPos = c_FightAggro.target.pos		
		ml_task_hub:Add(newTask.Create(), IMMEDIATE_GOAL, TP_IMMEDIATE)
		c_FightAggro.target = nil
	else
		ml_log("e_FightAggro found no target")
	end
	return ml_log(false)
end


--: add this cne to move to a random position on the mesh most likely in levelrange of the player
c_movetorandom = inheritsFrom(ml_cause)
e_movetorandom = inheritsFrom(ml_effect)
c_movetorandom.randompoint = nil
c_movetorandom.randompointreached = false
c_movetorandom.randomdistance = math.random(750,5000)
function c_movetorandom:evaluate()
	if (c_movetorandom.randompoint == nil) then
				
		-- Walk to Random Point in our levelrange
		if ( TableSize(gw2_datamanager.levelmap) > 0 ) then
			local pos = gw2_datamanager.GetRandomPositionInLevelRange( ml_global_information.Player_Level )
			if (TableSize(pos) > 0 ) then
				-- make sure the position can be reached
				if ( ValidTable(NavigationManager:GetPath(ml_global_information.Player_Position.x,ml_global_information.Player_Position.y,ml_global_information.Player_Position.z,pos.x,pos.y,pos.z))) then
					d("c_movetorandom.randompoint path found")
					c_movetorandom.randompoint = pos
					c_movetorandom.randompointreached = false
					c_movetorandom.randomdistance = math.random(750,5000)
				else
					d("c_movetorandom.randompoint no path found")
				end
			end
		end
	end

	-- 2nd attempt to find a random point
	if (c_movetorandom.randompoint == nil) then
	
		local pos = Player:GetRandomPoint(5000) -- 5000 beeing mindistance to player
		if ( pos and pos ~= 0) then
			if ( ValidTable(NavigationManager:GetPath(ml_global_information.Player_Position.x,ml_global_information.Player_Position.y,ml_global_information.Player_Position.z,pos.x,pos.y,pos.z))) then
				c_movetorandom.randompoint = pos
				c_movetorandom.randompointreached = false
				c_movetorandom.randomdistance = math.random(750,5000)
			end
		end
	end
	
	if (c_movetorandom.randompoint and not c_movetorandom.randompointreached) then			
		return true
	end		
		
	c_movetorandom.randompoint = nil
    return false
end
function e_movetorandom:execute()
	ml_log("MoveToRandomPoint ")
	if (c_movetorandom.randompoint) then
		
		local rpos = c_movetorandom.randompoint
		
		if ValidTable(rpos) then
			local dist = Distance3D(ml_global_information.Player_Position.x,ml_global_information.Player_Position.y,ml_global_information.Player_Position.z,rpos.x,rpos.y,rpos.z)
			
			if  (dist < c_movetorandom.randomdistance) then
				c_movetorandom.randompointreached = true
				c_movetorandom.randompoint = nil
				return ml_log(true)
			else						
				ml_log(", distance " .. math.floor(dist) .. " -> ")
				if ( not gw2_unstuck.HandleStuck() ) then
					local result = tostring(Player:MoveTo(rpos.x,rpos.y,rpos.z,250,false,false,false))
					if (tonumber(result) >= 0) then
						return ml_log(true)
					end
				end
			end
		end
	end
	
	return ml_log(false)
end

-- Looting chests and normal lootable enemies
c_Looting = inheritsFrom( ml_cause )
e_Looting = inheritsFrom( ml_effect )
c_Looting.target = nil
function c_Looting:evaluate()
	--ml_log("c_Looting")
	-- Find new loot target.
	if (c_Looting.target == nil) then
		local ChestCIDs = "17698,198260,232192,232193,232194,262863,236384"
		c_Looting.target = (GadgetList("onmesh,lootable,selectable,nearest,maxdistance=2500,contentID="..ChestCIDs) or CharacterList("nearest,lootable,onmesh,maxdistance=3000"))
	end
	-- Check if we need to loot and have a valid target and enough space to store it.
	if (ValidTable(c_Looting.target) and ml_global_information.Player_Inventory_SlotsFree > 0) then
		return true
	end
	
	c_Looting.target = nil
	return false
end

function e_Looting:execute()	
	ml_log("Looting ")
	c_Looting.target = (GadgetList("onmesh,lootable,selectable,shortestpath,maxdistance=3500,contentID="..ChestCIDs) or CharacterList("shortestpath,lootable,onmesh,maxdistance=3500"))
	if ( ValidTable(c_Looting.target) ) then 
		local target = select(2,next(c_Looting.target))
		-- Check for valid target.
		if (target and target.lootable) then
			
			-- We are in range to loot
			if (target.isInInteractRange) then
				gw2_common_functions.NecroLeaveDeathshroud()
				ml_log(": Interacting started.")
				if ( ml_global_information.Player_IsMoving ) then Player:StopMovement() end
				Player:Interact(target.id)
			
			-- Loot not in range, walk there.			
			else
				ml_log(": Walking to Chest.")
				gw2_common_functions.MoveOnlyStraightForward()
				-- Moving to target position.
				local tPos = target.pos
				if ( not gw2_unstuck.HandleStuck() ) then
					Player:MoveTo(tPos.x,tPos.y,tPos.z,50,false,false,false)
				end
			end		
		end
	end
	-- Target gone? Stop moving and delete target.
	if ( ml_global_information.Player_IsMoving ) then Player:StopMovement() end
	ml_log(": Looting done.")
	c_Looting.target = nil
end


c_fleeToSafety = inheritsFrom( ml_cause )
e_fleeToSafety = inheritsFrom( ml_effect )
c_fleeToSafety.fleeing = false
function c_fleeToSafety:evaluate()
	
	-- Check if were alive and if were low on health or already fleeing.
	if (ml_global_information.Player_Alive and ml_global_information.Player_InCombat and ml_global_information.Player_Health.percent < 15) then
		local safespot = select(2,next(WaypointList("onmesh,notcontested,samezone,mindistance=250,nearest")))
		local nmbrEnemies = TableSize(CharacterList("aggro,alive"))
		local target = Player:GetTarget()
		local tHealth = (target == nil and 100 or target.health.percent)
		-- Check for safe-spot and enemy number or enemy health.
		if (safespot and (nmbrEnemies > 1 or tHealth > 50)) then
			return true
		end
	elseif ( ml_global_information.Player_Alive and c_fleeToSafety.fleeing == true) then
		return true
	end
	
	return false
end
function e_fleeToSafety:execute()	
	ml_log("e_fleeToSafety")
	-- Check if we still need to flee
	c_fleeToSafety.fleeing = (ml_global_information.Player_Health.percent < 85)
	-- Heal if we can
	gw2_skill_manager.Heal()
	-- Find enemies.
	local nmbrEnemies = CharacterList("aggro,alive")
	-- Enemies found, keep fleeing.
	if (ValidTable(nmbrEnemies)) then
		ml_log(": Walking to Safe-spot.")
		-- Find safespot.
		local safespot = select(2,next(WaypointList("onmesh,notcontested,samezone,mindistance=250,nearest"))).pos
		if ( safespot ) then 
			gw2_common_functions.MoveOnlyStraightForward()
			Player:MoveTo(safespot.x,safespot.y,safespot.z,50,false,true,true)
		end
		
	-- No enemies found, safe-spot found stop moving and wait to heal.	
	else
		ml_log(": Found Safe-spot, waiting to heal.")
		if ( ml_global_information.Player_IsMoving ) then Player:StopMovement() end
	end
end


c_waitToHeal = inheritsFrom( ml_cause )
e_waitToHeal = inheritsFrom( ml_effect )
c_waitToHeal.hpPercent = math.random(70,85)
function c_waitToHeal:evaluate()
	--d("c_waitToHeal")
	-- Check players health, if below set value wait to heal.
	local conditions = "736,720,737,722,861,721,791,727,738,742,723"
	local buffs = Player.buffs
	return ( not ml_global_information.Player_InCombat and (ml_global_information.Player_Health.percent < c_waitToHeal.hpPercent or gw2_common_functions.BufflistHasBuffs(buffs,conditions)) )
end
function e_waitToHeal:execute()	
	ml_log("WaitToHeal")
	-- Set new random HP trigger.
	c_waitToHeal.hpPercent = math.random(70,85)
	
	-- If necro check for deathshroud.
	gw2_common_functions.NecroLeaveDeathshroud()
	-- Stop Player movement.
	if ( ml_global_information.Player_IsMoving ) then Player:StopMovement() end
	-- Try skillmanager to heal
	gw2_skill_manager.Heal()	
end

-- Finish downed enemies
c_FinishEnemy = inheritsFrom( ml_cause )
e_FinishEnemy = inheritsFrom( ml_effect )
e_FinishEnemy.tmr = 0
e_FinishEnemy.threshold = 2000
function c_FinishEnemy:evaluate()
    return ml_global_information.Player_SwimState == 0 and ml_global_information.Player_Health.percent > 15 and TableSize(CharacterList("nearest,downed,aggro,attackable,maxdistance=1200,onmesh")) > 0
end
function e_FinishEnemy:execute()
	ml_log(" Finish Enemy ")
	local EList = CharacterList("nearest,downed,aggro,attackable,maxdistance=1200,onmesh")
	if ( EList ) then
		local id,entity = next (EList)
		if ( id and entity ) then
			
			if (not entity.isInInteractRange) then
				-- MoveIntoInteractRange
				local tPos = entity.pos
				if ( tPos ) then
					gw2_common_functions.MoveOnlyStraightForward()
					if ( not gw2_unstuck.HandleStuck() ) then
						local navResult = tostring(Player:MoveTo(tPos.x,tPos.y,tPos.z,50,false,false,false))		
						if (tonumber(navResult) < 0) then
							d("e_FinishEnemy result: "..tonumber(navResult))					
						end
					end
					if ( ml_global_information.Now - e_FinishEnemy.tmr > e_FinishEnemy.threshold ) then
						e_FinishEnemy.tmr = ml_global_information.Now
						e_FinishEnemy.threshold = math.random(1500,5000)
						gw2_skill_manager.Heal()
					end
					ml_log("MoveTo_FinishHim..")
					return true
				end
			else
				-- Grab that thing
				if ( ml_global_information.Player_IsMoving ) then Player:StopMovement() end 
				
				local t = Player:GetTarget()
				if ( entity.selectable and (not t or t.id ~= id )) then
					Player:SetTarget( id )
				else
					
					-- If necro check for deathshroud.
					gw2_common_functions.NecroLeaveDeathshroud()
					
					
					if ( Player.castinfo.duration == 0 ) then
						Player:Interact( id )
						ml_log("Start Finishing Enemy..")
						ml_global_information.Wait(1000)						
					else
						ml_log("Finishing Enemy....")
					end
					return ml_log(true)
				end			
			end
		end
	end
	return ml_log(false)
end