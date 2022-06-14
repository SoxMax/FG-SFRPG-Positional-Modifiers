--
-- Add functionality to handle ranged attack distances and proximities
--
--

local function getAttackType(rRoll)
	local sAttackType = nil;
	if rRoll.sType == "attack" then
		sAttackType = string.match(rRoll.sDesc, "%[ATTACK.*%((%w+)%)%]");
		if not sAttackType then
			sAttackType = "M";
		end
	elseif rRoll.sType == "cmb" then
		sAttackType = "M";
	elseif rRoll.sType == "ab" then
		sAttackType = "AB";
	end
	return sAttackType
end

local function getPcWeaponRange(playerNode, sWeaponUsed)
	for _,vWeaponNode in pairs(DB.getChildren(playerNode, "weaponlist")) do
		local sWeaponName = DB.getValue(vWeaponNode, "name"):lower()
		local nWeaponType = DB.getValue(vWeaponNode, "type")  -- 0 M; 1 R; 2 CMB
		if nWeaponType == 1 and (sWeaponName == sWeaponUsed) then
			local nWeaponRange = DB.getValue(vWeaponNode, "rangeincrement", 0)
			local sSubType = DB.getValue(vWeaponNode, "subtype", "")
			local sSpecial = DB.getValue(vWeaponNode, "special", "")
			local nMaxIncrements = 10
			if sSubType:lower() == "grenade" or string.match(sSpecial:lower(), "thrown") then
				nMaxIncrements = 5
			end
			return nWeaponRange, nMaxIncrements
		end
	end
end

local function getNpcWeaponRange(sWeaponUsed)
	-- For an NPC, get the standard range data for the weapon type
	-- Check for a match against the weapon data
	local rangeData = WeaponRangeData.weaponranges[sWeaponUsed];
	if rangeData then
		return rangeData[1], rangeData[2]
	else
		-- It wasn't found; check for a match vs each entry in the
		-- data table in case this weapon has additional words (Mwk, silver, etc.)
		for sWeaponName, tWeaponRangeData in pairs(WeaponRangeData.weaponranges) do
			if string.match(sWeaponUsed, sWeaponName) then
				return tWeaponRangeData[1], tWeaponRangeData[2]
			end
		end
	end
end

local function getWeaponRange(rSource, rRoll)
	-- Get the name of the weapon being used
	sourceNode = ActorManager.getCreatureNode(rSource)
	local sWeaponUsed = StringManager.trim(string.match(rRoll.sDesc, "%]([^%[]*)")):lower()
	if ActorManager.isPC(sourceNode) then
		return getPcWeaponRange(sourceNode, sWeaponUsed)
	else
		-- NPC Handling
	end
end

local function hasFeat(actorNode, sFeat)

	local function npcHasFeat(ctNode, sFeat)

		local sLowerFeat = StringManager.trim(string.lower(sFeat));
		local sFeatList = DB.getValue(ctNode, "feats");

		if sFeatList then
			return string.match(StringManager.trim(string.lower(sFeatList)), sLowerFeat);
		end

		return false

	end

	if not actorNode then
		return false;
	end

	if ActorManager.isPC(actorNode) then
		return CharManager.hasFeat(actorNode, sFeat);
	else
		return npcHasFeat(actorNode, sFeat);
	end
end

local function modRangedAttack(rSource, rTarget, rRoll)
	if rSource and rTarget and getAttackType(rRoll) == 'R' then
		local weaponRange, maxIncrements = getWeaponRange(rSource, rRoll)
		if weaponRange and maxIncrements then
			local sourceToken = CombatManager.getTokenFromCT(rSource.sCTNode)
			local targetToken = CombatManager.getTokenFromCT(rTarget.sCTNode)
			local nDistanceBetweenTokens = Token.getDistanceBetween(sourceToken, targetToken)
			if(nDistanceBetweenTokens > weaponRange) then
				local rangeIncrement = math.ceil(nDistanceBetweenTokens / weaponRange)
				if rangeIncrement > maxIncrements then
					local tMsg = {sender = "", font = "emotefont", mood = "ooc"}
					local nMaxRange = maxIncrements * weaponRange;
					local weaponName = StringManager.trim(string.match(rRoll.sDesc, "%]([^%[]*)"))
					tMsg.text = "Target " .. rTarget.sName .. " at range " .. nDistanceBetweenTokens .. " is beyond " .. weaponName "'s max range of " .. nMaxRange
					Comm.deliverChatMessage(tMsg)
				end
				local rangePenalty = -2
				if hasFeat(ActorManager.getCreatureNode(rSource), "Far Shot") then
					rangePenalty = -1
				end
				local rangeMod = (rangeIncrement - 1) * rangePenalty
				rRoll.nMod = rRoll.nMod + rangeMod
				rRoll.sDesc = rRoll.sDesc .. " [RANGE " .. rangeMod .. "]"
			end
		end
	end
end

function handleAttack(rSource, rTarget, rRoll)
	ActionAttack.modAttack(rSource, rTarget, rRoll)
	modRangedAttack(rSource, rTarget, rRoll)
end

function onInit()
	ActionsManager.registerModHandler("attack", handleAttack);
end
