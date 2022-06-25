-- This extension contains 5e SRD mounted combat rules.  For license details see file: Open Gaming License v1.0a.txt

EFFECTS = "effects"
INIT_RESULT = "initresult"
IS_FGC = false
LABEL = "label"
LAST_DRAG_INFO = nil
MAX = "max"
MOUNT = "mount"
MOUNT_ACTIONS = " It moves as you direct it, and it has only three action options: Dash, Disengage, and Dodge. If the mount provokes an opportunity attack while you're on it, the attacker can target you or the mount."
MOUNTTRACKER_CLIENT_CHAT = "MOUNTTRACKER_CLIENT_CHAT"
MOUNTTRACKER_CONTROLLED_MOUNT_SKIP = "MOUNTTRACKER_CONTROLLED_MOUNT_SKIP"
MOUNTTRACKER_ENFORCE_SIZE = "MOUNTTRACKER_ENFORCE_SIZE"
MOUNTTRACKER_VERBOSE = "MOUNTTRACKER_VERBOSE"
OFF = "off"
ON = "on"
OOB_MSGTYPE_ATTACKFROMMOUNT = "mt_attackfrommount"
OOB_MSGTYPE_MOUNT = "mt_mount"
OOB_MSGTYPE_DISMOUNT = "mt_dismount"
PRONE_RULES = "If an effect moves your mount against its will while you're on it, you must succeed on a DC 10 Dexterity saving throw or fall off the mount, landing prone in a space within 5 feet of it. If you're knocked prone while mounted, you must make the same saving throw. If your mount is knocked prone, you can use your reaction to dismount it as it falls and land on your feet. Otherwise, you are dismounted and fall prone in a space within 5 feet it."
SIZE_GARGANTUAN = "Gargantuan"
SIZE_HUGE = "Huge"
SIZE_LARGE = "Large"
SIZE_MEDIUM = "Medium"
SIZE_SMALL = "Small"
SIZE_TINY = "Tiny"
UCMOUNT = "ucmount"
USER_ISHOST = false

ActionAttack_onAttack = nil
CombatManager_onDrop = nil
EffectManager_addEffect = nil

function onInit()
	IS_FGC = checkFGC()
	local option_header = "option_header_mounttracker"
	local option_val_off = "option_val_off"
	local option_entry_cycler = "option_entry_cycler"
	OptionsManager.registerOption2(MOUNTTRACKER_CONTROLLED_MOUNT_SKIP, false, option_header, "option_label_MOUNTTRACKER_CONTROLLED_MOUNT_SKIP", option_entry_cycler,
	{ labels = option_val_off, values = OFF, baselabel = "option_val_on", baseval = ON, default = ON })
	OptionsManager.registerOption2(MOUNTTRACKER_ENFORCE_SIZE, false, option_header, "option_label_MOUNTTRACKER_ENFORCE_SIZE", option_entry_cycler,
	{ labels = option_val_off, values = OFF, baselabel = "option_val_on", baseval = ON, default = ON })
	OptionsManager.registerOption2(MOUNTTRACKER_CLIENT_CHAT, false, option_header, "option_label_MOUNTTRACKER_CLIENT_CHAT", option_entry_cycler,
	{ labels = option_val_off, values = OFF, baselabel = "option_val_on", baseval = ON, default = ON })
	OptionsManager.registerOption2(MOUNTTRACKER_VERBOSE, false, option_header, "option_label_MOUNTTRACKER_VERBOSE", option_entry_cycler,
	{ baselabel = "option_val_max", baseval = MAX, labels = "option_val_standard|" .. option_val_off, values = "standard|" .. OFF, default = MAX })

	USER_ISHOST = User.isHost()

	if USER_ISHOST then
		CombatManager.setCustomTurnStart(onTurnStartEvent)
		OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_ATTACKFROMMOUNT, handleAttackFromMount)
		OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_MOUNT, handleMount)
		OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_DISMOUNT, handleDismount)

		Comm.registerSlashHandler("mt", processChatCommand) -- a command for status of current CT actor and also for subcommands (i.e. clear).
		Comm.registerSlashHandler("mounttracker", processChatCommand) -- a command for status of current CT actor and also for subcommands (i.e. clear).
		Comm.registerSlashHandler(UCMOUNT, processUncontrolledMountChatCommand)
		Comm.registerSlashHandler(MOUNT, processControlledMountChatCommand)
		Comm.registerSlashHandler("dismount", processDismountChatCommand)
			-- TODO: This will be the new way of doing things once they deprecate Comm.registerSlashHandler() which is coming soon.
		--ChatManager.registerSlashCommand(MOUNT, processChatCommand)

		EffectManager_addEffect = EffectManager.addEffect
		EffectManager.addEffect = addEffect

		if CombatDropManager then
			CombatManager_onDrop = CombatDropManager.onLegacyDropEvent
			CombatDropManager.onLegacyDropEvent = onDrop
		else
			CombatManager_onDrop = CombatManager.onDrop
			CombatManager.onDrop = onDrop
		end
	end

	ActionAttack_onAttack = ActionAttack.onAttack
	ActionAttack.onAttack = onRollAttack
	ActionsManager.registerResultHandler("attack", onRollAttack)
end

function addEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	EffectManager_addEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	if rNewEffect.sName == "Prone" then
		local nodeRiderEffect = getRiderEffectNode(nodeCT)
		local nodeMountEffect = getMountEffectNode(nodeCT)
		if (nodeRiderEffect or nodeMountEffect) then
			if nodeRiderEffect then
				local sRider = getMountOrRiderValueFromEffectNode(nodeRiderEffect)
				local nodeRider = getMountOrRiderCombatTrackerNode(sRider)
				local nodeMountEffectFromEffectRider = getMountEffectNode(nodeRider)
				if nodeMountEffectFromEffectRider then
					nodeMountEffectFromEffectRider.delete()
				end

				nodeRiderEffect.delete()
			end

			if not checkVerbosityOff() then
				displayChatMessage(PRONE_RULES, not checkClientChat())
			end
		end
	end
end

function checkClientChat()
	return OptionsManager.isOption(MOUNTTRACKER_CLIENT_CHAT, ON)
end

-- Alphebetical list of functions below (onInit() above was an exception)
function checkControlledMountSkip()
	return OptionsManager.isOption(MOUNTTRACKER_CONTROLLED_MOUNT_SKIP, ON)
end

function checkEnforceSizeRule()
	return OptionsManager.isOption(MOUNTTRACKER_ENFORCE_SIZE, ON)
end

function checkFGC()
	local nMajor, nMinor, nPatch = Interface.getVersion()
	if nMajor <= 2 then return true end
	if nMajor == 3 and nMinor <= 2 then return true end
	return nMajor == 3 and nMinor == 3 and nPatch <= 15
end

function checkVerbosityMax()
	return OptionsManager.isOption(MOUNTTRACKER_VERBOSE, MAX)
end

function checkVerbosityOff()
	return OptionsManager.isOption(MOUNTTRACKER_VERBOSE, OFF)
end

-- Function that walks the CT nodes and deletes the mount effects from them.
function clearAllMountTrackerDataFromCT(bInvalidOnly)
	-- Walk the CT resetting all names.
	for _,nodeCT in pairs(DB.getChildren(CombatManager.CT_LIST)) do
		local bInvalid = false

		local nodeMountEffect = getMountEffectNode(nodeCT)
		if nodeMountEffect then
			local sEffectMountName = getMountOrRiderValueFromEffectNode(nodeMountEffect)
			local nodeMountOfEffectRider = getMountOrRiderCombatTrackerNode(sEffectMountName)
			if not hasRider(nodeMountOfEffectRider, ActorManager.getDisplayName(nodeCT)) then
				bInvalid = true
			end
		end

		local nodeRiderEffect = getRiderEffectNode(nodeCT)
		if nodeRiderEffect then
			local sEffectRiderName = getMountOrRiderValueFromEffectNode(nodeRiderEffect)
			local nodeRiderOfEffectMount = getMountOrRiderCombatTrackerNode(sEffectRiderName)
			if not hasMount(nodeRiderOfEffectMount, ActorManager.getDisplayName(nodeCT)) then
				bInvalid = true
			end
		end

		if not bInvalidOnly or (bInvalidOnly and bInvalid) then
			deleteAllMountOrRiderEffects(nodeCT)
		end
	end
end

-- Deletes all of the mount or rider effects for a CT node (no expiration warning because this is cleanup and not effect usage causing the deletion).
function deleteAllMountOrRiderEffects(nodeCT)
	if not nodeCT then return end

	for _,nodeEffect in pairs(DB.getChildren(nodeCT, EFFECTS)) do
		if isMountOrRiderEffectNode(nodeEffect) then
			nodeEffect.delete()
		end
	end
end

-- TODO: Refactor opportunity to extract common verify method?  Similar things done in a couple places like 'clearAll...' and 'performMountCommand...'
function deletePairedEffectNode(nodeCT)
	local nodeMountEffect = getMountEffectNode(nodeCT)
	if nodeMountEffect then
		local sEffectMountName = getMountOrRiderValueFromEffectNode(nodeMountEffect)
		local nodeMountOfEffectRider = getMountOrRiderCombatTrackerNode(sEffectMountName)
		if hasRider(nodeMountOfEffectRider, ActorManager.getDisplayName(nodeCT)) then
			local nodeRiderEffectOfMount = getRiderEffectNode(nodeMountOfEffectRider)
			if nodeRiderEffectOfMount then
				nodeRiderEffectOfMount.delete()
			end
		end
	end

	local nodeRiderEffect = getRiderEffectNode(nodeCT)
	if nodeRiderEffect then
		local sEffectRiderName = getMountOrRiderValueFromEffectNode(nodeRiderEffect)
		local nodeRiderOfEffectMount = getMountOrRiderCombatTrackerNode(sEffectRiderName)
		if hasMount(nodeRiderOfEffectMount, ActorManager.getDisplayName(nodeCT)) then
			local nodeMountEffectOfRider = getMountEffectNode(nodeRiderOfEffectMount)
			if nodeMountEffectOfRider then
				nodeMountEffectOfRider.delete()
			end
		end
	end
end

-- Puts a message in chat that is broadcast to everyone attached to the host (including the host) if bSecret is true, otherwise local only.
function displayChatMessage(sFormattedText, bSecret)
	if not sFormattedText then return end

	local msg = {font = "msgfont", icon = "mount_icon", secret = bSecret, text = sFormattedText}

	-- deliverChatMessage() is a broadcast mechanism, addChatMessage() is local only.
	if bSecret then
		Comm.addChatMessage(msg)
	else
		Comm.deliverChatMessage(msg)
	end
end

function displayDebilitatingConditionChatMessage(vActor, sCondition)
	local sText = string.format("'%s' is %s, can't mount/dismount.",
								ActorManager.getDisplayName(vActor),
								sCondition)
	displayChatMessage(sText, not checkClientChat())
end

function displayProcessAttackFromMount(rSource, rTarget, rRoll)
	-- if no source or no roll then exit, skipping StealthTracker processing.
	if not rSource or not rSource.sCTNode or rSource.sCTNode == "" then return end

	local sRollDesc = rRoll.sDesc
	if not USER_ISHOST then
		-- For clients notify of an action from mount and then exit.  Host handler will pick up message and run code after this block.
		notifyAttackFromMount(rSource.sCTNode, (rTarget and rTarget.sCTNode) or "", rRoll)
		return
	end

	-- HOST ONLY PROCESSING STARTS HERE ----------------------------------------------------------------------------------------------------------

	local aOutput = {}
	local nodeSource = ActorManager.getCTNode(rSource)
	if nodeSource then
		if getRiderEffectNode(nodeSource) then
			insertFormattedTextWithSeparatorIfNonEmpty(aOutput, "Attack was made by the mount.  Is is uncontrolled?  A controlled mount can only Dash, Disengage, and Dodge.")
		elseif getMountEffectNode(nodeSource) then
			insertFormattedTextWithSeparatorIfNonEmpty(aOutput, "Attack was made by a mounted combatant.")
		end
	end

	if CombatDropManager == nil or isHit(rRoll) then
		local nodeTarget = ActorManager.getCTNode(rTarget)
		if nodeTarget then
			if getRiderEffectNode(nodeTarget) or getMountEffectNode(nodeTarget) then
				insertFormattedTextWithSeparatorIfNonEmpty(aOutput, "Target is a mounted combatant pair, special rules apply for prone and forced movement.")

				if sRollDesc and sRollDesc:match("%[OPPORTUNITY%]") then
					insertFormattedTextWithSeparatorIfNonEmpty(aOutput, "The attacker can choose the mount or rider as the target of this opportunity attack.")
				end

				insertFormattedTextWithSeparatorIfNonEmpty(aOutput, "Movement against will or rider knocked prone is DC 10 Dex save or fall off mount and prone w/in 5 ft. " ..
																	"If mount knocked prone, rider reaction to dismount and land on feet else dismounted and prone w/in 5 ft.")
			end
		end
	end

	displayTableIfNonEmpty(aOutput)
end

function displayTableIfNonEmpty(aTable)
	aTable = validateTableOrNew(aTable)
	if #aTable > 0 then
		local sDisplay = table.concat(aTable, "\r")
		displayChatMessage(sDisplay, not checkClientChat())
	end
end

-- Function to expire the last found stealth effect in the CT node's effects table.  An explicit expiration is needed because the built-in expiration only works if the coded effect matches a known roll or action type (i.e. ATK:3 will expire on attack roll).
function expireMountOrRiderEffectOnCTNode(nodeCT)
	if not nodeCT then return end

	local aSortedCTNodes = getOrderedEffectsTableFromCTNode(nodeCT)
	if not aSortedCTNodes then return end

	local nodeLastEffectWithMountOrRider

	-- Walk the effects in order so that the last one added is taken in case they are stacked.
	for _, nodeEffect in pairs(aSortedCTNodes) do
		if isMountOrRiderEffectNode(nodeEffect) then
			nodeLastEffectWithMountOrRider = nodeEffect
		end
	end

	-- If an effect node was found walking the list, expire the effect.
	if nodeLastEffectWithMountOrRider then
		EffectManager.expireEffect(nodeCT, nodeLastEffectWithMountOrRider, 0)
	end
end

function getActorDebilitatingCondition(vActor)
	local rActor = ActorManager.resolveActor(vActor)
	if not rActor then return nil end

	local aConditions = { -- prioritized
		"unconscious",
		"incapacitated",
		"stunned",
		"paralyzed",
		"petrified",
		"grappled",
		"prone",
		"stable" -- FG, not 5e
	}

	for _,sCondition in ipairs(aConditions) do
		if EffectManager5E.hasEffect(rActor, sCondition) then return sCondition end
	end

	return nil
end

function getEffectNode(nodeCT, sEffect, bTagOnly)
	if not nodeCT or not sEffect then return nil end

	local aSorted = getOrderedEffectsTableFromCTNode(nodeCT)
	local sEffectPattern = "^%s*" .. sEffect:lower() .. ":[^;]*$"
	if bTagOnly then
		sEffectPattern = "^%W*" .. sEffect:lower() .. "%W*$"
	end

	-- Walk the effects in order so that the last one added is taken in case they are stacked.  If a duplicate Stealth effect is found, remove subsequent ones.
	for _, nodeEffect in pairs(aSorted) do

		local sEffectLabel = DB.getValue(nodeEffect, LABEL, ""):lower()

		-- Let's break that effect up into it's components (i.e. tokenize on ;, from CoreRPG)
		local aEffectComponents = EffectManager.parseEffect(sEffectLabel)

		-- Look through each of the effect segments matching Mount:
		for _, component in ipairs(aEffectComponents) do
			local sMatch = string.match(component, sEffectPattern)
			if sMatch then
				return nodeEffect
			end
		end
	end

	return nil
end

function getMountEffectNode(nodeCT)
	return getEffectNode(nodeCT, MOUNT)
end

function getMountOrRiderCombatTrackerNode(sActorName)
	if not sActorName then return nil end

	local nodeFound = nil
	for _, nodeCT in pairs(DB.getChildren(CombatManager.CT_LIST)) do
		local rActor = ActorManager.resolveActor(nodeCT)
		local sPattern = "^" .. sActorName:lower()
		if rActor and string.match(rActor.sName:lower(), sPattern) then
			if not nodeFound then
				nodeFound = nodeCT
			else
				return nil
			end
		end
	end

	return nodeFound
end

function getMountOrRiderValueFromEffectNode(nodeEffect)
	if not nodeEffect then return end

	local sEffectLabel = DB.getValue(nodeEffect, LABEL, "")

	-- Let's break that effect up into it's components (i.e. tokenize on ;)
	local aEffectComponents = EffectManager.parseEffect(sEffectLabel)

	local sExtractedMount
	-- Take the last Mount value found, in case it was manually entered and accidentally duplicated (iterate through all of the components).
	for _, component in ipairs(aEffectComponents) do
		local sMatch = string.match(component, "^%s*Mount:%s*(.+)%s*$") or
					   string.match(component, "^%s*Rider:%s*(.+)%s*$")
		if sMatch then
			sExtractedMount = sMatch
		end
	end

	return sExtractedMount
end

-- For the provided CT node, get an ordered list (alphabetical) of the effects on it.
function getOrderedEffectsTableFromCTNode(nodeCT)
	local aCTNodes = {}
	for _, nodeEffect in pairs(DB.getChildren(nodeCT, EFFECTS)) do
		table.insert(aCTNodes, nodeEffect)
	end

	table.sort(aCTNodes, function (a, b) return a.getName() < b.getName() end)
	return aCTNodes
end

function getRiderEffectNode(nodeCT)
	return getEffectNode(nodeCT, "rider")
end

function getSize(nodeCT)
	return DB.getText(nodeCT, "size", "")
end

function getSpeed(nodeCT)
	return DB.getText(nodeCT, "speed", "")
end

-- Handler for the message to do an attack from a mount.
function handleAttackFromMount(msgOOB)
	if not msgOOB or not msgOOB.type then return end

	if msgOOB.type == OOB_MSGTYPE_ATTACKFROMMOUNT then
		if not msgOOB.sSourceCTNode or not msgOOB.sTargetCTNode then return end

		local rSource = ActorManager.resolveActor(msgOOB.sSourceCTNode)
		if not rSource then return end

		local rTarget = ActorManager.resolveActor(msgOOB.sTargetCTNode)
		local rRoll = {}
		rRoll.sDesc = msgOOB.sRollDesc
		rRoll.aMessages = {}
		if msgOOB.sIsHit == "true" then
			table.insert(rRoll.aMessages, "HIT")
		end

		displayProcessAttackFromMount(rSource, rTarget, rRoll)
	end
end

function handleMount(msgOOB)
	if not msgOOB or not msgOOB.type or msgOOB.type ~= OOB_MSGTYPE_MOUNT then return end

	if not msgOOB.sTargetCTNode then return end

	local stringToBoolean = { ["true"] = true, ["false"] = false }
	processMountChatCommand(msgOOB.sTargetCTNode, not stringToBoolean[msgOOB.sControlledBoolean])
end

function handleDismount(msgOOB)
	if not msgOOB or not msgOOB.type or msgOOB.type ~= OOB_MSGTYPE_DISMOUNT then return end

	processDismountChatCommand(msgOOB.sActorName)
end

function hasEffectColonValue(nodeEffect, sEffect, sValue)
	if not nodeEffect or not sEffect or sEffect == "" or not sValue or sValue == "" then return false end

	local sEffectLabel = DB.getValue(nodeEffect, LABEL, "")
	-- Let's break that effect up into it's components (i.e. tokenize on ;)
	local aEffectComponents = EffectManager.parseEffect(sEffectLabel)

	-- Take the last Mount value found, in case it was manually entered and accidentally duplicated (iterate through all of the components).
	for _, component in ipairs(aEffectComponents) do
		if string.match(component, "^%W*" .. sEffect .. ":%W*" .. sValue .. "%W*$") then
			return true
		end
	end

	return false
end

function hasMount(nodeCT, sMountName)
	local sMountEffectName = "Mount"
	local nodeMountEffect = getEffectNode(nodeCT, sMountEffectName)
	return hasEffectColonValue(nodeMountEffect, sMountEffectName, sMountName)
end

function hasRider(nodeCT, sRiderName)
	local sRiderEffectName = "Rider"
	local nodeRiderEffect = getEffectNode(nodeCT, sRiderEffectName)
	return hasEffectColonValue(nodeRiderEffect, sRiderEffectName, sRiderName)
end

function insertBlankSeparatorIfNotEmpty(aTable)
	if #aTable > 0 then table.insert(aTable, "") end
end

function insertFormattedTextWithSeparatorIfNonEmpty(aTable, sFormattedText)
	insertBlankSeparatorIfNotEmpty(aTable)
	table.insert(aTable, sFormattedText)
end

function isHit(rRoll)
	if not rRoll or not rRoll.aMessages then return false end

	local isHit = false
	for _, value in pairs(rRoll.aMessages) do
		if value:match("HIT") then
			isHit = true
			break
		end
	end

	return isHit
end

function isMountLargerThanRider(sMount, sRider)
	if sRider == SIZE_MEDIUM then
		return not (sMount == SIZE_TINY or sMount == SIZE_SMALL or sMount == SIZE_MEDIUM)
	end

	if sRider == SIZE_SMALL then
		return not (sMount == SIZE_TINY or sMount == SIZE_SMALL)
	end

	if sRider == SIZE_LARGE then
		return not (sMount == SIZE_TINY or sMount == SIZE_SMALL or sMount == SIZE_MEDIUM or sMount == SIZE_LARGE)
	end

	if sRider == SIZE_TINY then
		return not sMount == SIZE_TINY
	end

	if sRider == SIZE_HUGE then
		return not (sMount == SIZE_TINY or sMount == SIZE_SMALL or sMount == SIZE_MEDIUM or sMount == SIZE_LARGE or sMount == SIZE_HUGE)
	end

	if sRider == SIZE_GARGANTUAN then
		return false
	end

	return false
end

function isMountOrRiderEffectNode(nodeEffect)
	if not nodeEffect then return false end

	local sEffectLabel = DB.getValue(nodeEffect, LABEL, ""):lower()

	-- Let's break that effect up into it's components (i.e. tokenize on ;)
	local aEffectComponents = EffectManager.parseEffect(sEffectLabel)

	-- Take the last Mount value found, in case it was manually entered and accidentally duplicated (iterate through all of the components).
	for _,component in ipairs(aEffectComponents) do
		if string.match(component, "^%s*mount:[^;]*$") or string.match(component, "^%s*rider:[^;]*$") then
			return true
		end
	end

	return false
end

function isTrap(nodeCT)
	return DB.getText(nodeCT, "type", ""):lower():match("trap") ~= nil
end

-- Function to notify the host of an attack from a mounted combatant.
function notifyAttackFromMount(sSourceCTNode, sTargetCTNode, rRoll)
	if not sSourceCTNode or not sTargetCTNode then return end

	-- Setup the OOB message object, including the required type.
	local msgOOB = {}
	msgOOB.type = OOB_MSGTYPE_ATTACKFROMMOUNT

	-- Capturing the username allows for the effect to be built so that it can be deleted by the client.
	msgOOB.sSourceCTNode = sSourceCTNode
	msgOOB.sTargetCTNode = sTargetCTNode
	msgOOB.sRollDesc = rRoll.sDesc
	msgOOB.sIsHit = tostring(isHit(rRoll))
	Comm.deliverOOBMessage(msgOOB, "")
end

function notifyDismount()
	-- Setup the OOB message object, including the required type.
	local msgOOB = {}
	msgOOB.type = OOB_MSGTYPE_DISMOUNT
	msgOOB.sUsername = User.getUsername()
	msgOOB.sActorName = ActorManager.getDisplayName(CombatManager.getActiveCT())

	Comm.deliverOOBMessage(msgOOB, "")
end

function notifyMount(sTarget, bUncontrolledMount)
	-- Setup the OOB message object, including the required type.
	local msgOOB = {}
	msgOOB.type = OOB_MSGTYPE_MOUNT

	msgOOB.sUsername = User.getUsername()
	msgOOB.sControlledBoolean = tostring(not bUncontrolledMount)
	msgOOB.sTargetCTNode = sTarget

	Comm.deliverOOBMessage(msgOOB, "")
end

function onDrop(nodetype, nodename, draginfo)
	-- I don't know why this weird hack is needed, but it prevents the drop from firing twice.  It is FGC only.
	if IS_FGC then
		if LAST_DRAG_INFO == draginfo and
		   LAST_NODE_NAME == nodename and
		   LAST_NODE_TYPE == nodetype then
			LAST_DRAG_INFO = nil
			LAST_NODE_NAME = nil
			LAST_NODE_TYPE = nil
			return
		end

		LAST_DRAG_INFO = draginfo
		LAST_NODE_NAME = nodename
		LAST_NODE_TYPE = nodetype
	end

	local nodeSourceCT = draginfo.getCustomData()
	local nodeTargetCT
	if CombatDropManager then
		nodeTargetCT = CombatManager.getCTFromNode(nodename.sCTNode)
	else
		nodeTargetCT = CombatManager.getCTFromNode(nodename)
	end

	if nodeSourceCT and nodeTargetCT then
		processMountChatCommand(ActorManager.getDisplayName(nodeTargetCT), Input.isControlPressed(), nodeSourceCT)
	end

	CombatManager_onDrop(nodetype, nodename, draginfo)
end

-- Attack roll handler
function onRollAttack(rSource, rTarget, rRoll)
	ActionAttack_onAttack(rSource, rTarget, rRoll)
	displayProcessAttackFromMount(rSource, rTarget, rRoll)
end

-- This function is one that the Combat Tracker calls if present at the start of a creatures turn.  Wired up in onInit() for the host only.
function onTurnStartEvent(nodeCurrentCTActor) -- arg is CT node
	clearAllMountTrackerDataFromCT(true)
	if checkVerbosityOff() then return end

	local rCurrentActor = ActorManager.resolveActor(nodeCurrentCTActor)
	local nodeMountEffect = getMountEffectNode(nodeCurrentCTActor)
	local nodeRiderEffect = getRiderEffectNode(nodeCurrentCTActor)
	local sMountActions = ""
	if checkVerbosityMax() then sMountActions = MOUNT_ACTIONS end

	if nodeMountEffect then
		local sMountName = getMountOrRiderValueFromEffectNode(nodeMountEffect)
		local nodeMount = getMountOrRiderCombatTrackerNode(sMountName)
		if hasRider(nodeMount, rCurrentActor.sName) then
			local sSpeed = getSpeed(nodeMount)
			-- Any mounted combat rules or detail needed on the rider's turn.
			local sMsg = string.format("'%s' is riding a mount (%s). Speed: %s%s", rCurrentActor.sName, sMountName, sSpeed, sMountActions)
			displayChatMessage(sMsg, not checkClientChat())
		end

		return
	elseif nodeRiderEffect then
		local sRiderName = getMountOrRiderValueFromEffectNode(nodeRiderEffect)
		local nodeRider = getMountOrRiderCombatTrackerNode(sRiderName)
		if hasMount(nodeRider, rCurrentActor.sName) then
			local sSpeed = getSpeed(nodeCurrentCTActor)
			local bHasSkipTurn = getEffectNode(nodeCurrentCTActor, "skipturn", true)
			if not bHasSkipTurn then
				local sMsg = string.format("'%s' is a mount being ridden by '%s'. Speed: %s%s", rCurrentActor.sName, sRiderName, sSpeed, sMountActions)
				displayChatMessage(sMsg, not checkClientChat())
			end
		end

		return
	end
end

-- Handler for the 'mt' slash commands in chat.
function processChatCommand(_, sParams)
	-- Only allow administrative subcommands when run on the host/DM system.
	local sFailedSubcommand = processHostOnlySubcommands(sParams)
	if sFailedSubcommand then
		displayChatMessage("Unrecognized subcommand: " .. sFailedSubcommand, true)
	end
end

-- Handler for the 'mount' slash commands in chat.  Needs to handle the uncontrolled subcommand (i.e. /mount uncontrolled [MountName])
-- TODO: If target mount/npc is intelligent (what int value? 6? 8?), it's always uncontrolled.
function processControlledMountChatCommand(_, sMountName)
	processMountChatCommand(sMountName, false)
end

-- Handler for the 'dismount' slash commands in chat.
function processDismountChatCommand(_, sRider)  -- TODO: If sParams is populated, dismount that user no matter the CT position.
	local nodeCT = getMountOrRiderCombatTrackerNode(sRider)
	if not nodeCT then
		nodeCT = CombatManager.getActiveCT()
	end

	if not nodeCT then return end

	local sCurrentActorName = ActorManager.getDisplayName(nodeCT)
	local nodeRiderEffect = getRiderEffectNode(nodeCT)
	if nodeRiderEffect then
		local sMsg = string.format("The current actor (%s) is a mount, dismount should occur on the rider's (%s) turn.", sCurrentActorName, getMountOrRiderValueFromEffectNode(nodeRiderEffect))
		displayChatMessage(sMsg, not checkClientChat())
		return
	end

	local nodeMountEffect = getMountEffectNode(nodeCT)
	if not nodeMountEffect then
		local sMsg = string.format("The current actor (%s) does not have a mount.", sCurrentActorName)
		displayChatMessage(sMsg, not checkClientChat())
		return
	end

	local sMountName = getMountOrRiderValueFromEffectNode(nodeMountEffect)
	if not sMountName then return end

	local nodeMount = getMountOrRiderCombatTrackerNode(sMountName)
	if not nodeMount then
		-- Unmatched pair, clean up.
		deleteAllMountOrRiderEffects(nodeCT)
		return
	end

	-- Check to make sure the rider doesn't have an effect/condition that would make speed zero or unable to do anything.
	local sCondition = getActorDebilitatingCondition(nodeCT)
	if sCondition then
		displayDebilitatingConditionChatMessage(nodeCT, sCondition)
		return
	end

	expireMountOrRiderEffectOnCTNode(nodeCT)
	expireMountOrRiderEffectOnCTNode(nodeMount)
	if not checkVerbosityOff() then
		-- TODO: Calculate the movement needed w/ getSpeed() but it only works as a number on pcs, string on npc that would need to be parsed (comma separated walk is default with no prefix).
		displayChatMessage("Once during your move, you can mount a creature that is within 5 feet of you or dismount. Doing so costs an amount of movement equal to half your speed.", not checkClientChat())
	end
end

-- Chat commands that are for host only
function processHostOnlySubcommands(sSubcommand)
	-- Default/empty subcommand - What does the current CT actor not perceive?
	if sSubcommand == "" then
		-- This is the default subcommand for the host (/mt with no subcommand). It will give a chat display of .
		return
	end

	-- This is a mount name, so if the main command is mount let's use it.  Otherwise, ignore.
	if sSubcommand:lower() == "clear" then
		clearAllMountTrackerDataFromCT()
		displayChatMessage("MountTracker effects cleared from Combat Tracker.", true)
		return
	end

	-- Fallthrough/unrecognized subcommand
	return sSubcommand
end

function processMountChatCommand(sMountName, bUncontrolledMount, nodeRiderExplicit)
	local nodeRider = nodeRiderExplicit
	if not nodeRider then
		nodeRider = CombatManager.getActiveCT()
		if not nodeRider then
			displayChatMessage("Combat is not active, which is required for MountTracker processing.", not checkClientChat())
			return
		end
	end

	local sRiderName = ActorManager.getDisplayName(nodeRider)
	local nodeMount = getMountOrRiderCombatTrackerNode(sMountName)
	if nodeRider == nodeMount then
		local sMsg = string.format("The rider and mount (%s) must be unique names.", ActorManager.getDisplayName(nodeRider))
		displayChatMessage(sMsg, not checkClientChat())
		return
	end

	if not nodeMount or not sMountName or sMountName == "" then
		displayChatMessage("The mount name must be specified and match an npc/pc mount in the Combat Tracker.", not checkClientChat())
		return
	end

	sMountName = ActorManager.getDisplayName(nodeMount)

	local nodeMountEffect = getMountEffectNode(nodeRider)
	if nodeMountEffect then
		-- Check mount validity.
		local sEffectMountName = getMountOrRiderValueFromEffectNode(nodeMountEffect)
		local nodeMountOfEffectRider = getMountOrRiderCombatTrackerNode(sEffectMountName)
		if hasRider(nodeMountOfEffectRider, sRiderName) then
			local sMsg = string.format("'%s' already has a mount.", sRiderName)
			displayChatMessage(sMsg, not checkClientChat())
			return
		end
	end

	local nodeRiderEffectOnRider = getRiderEffectNode(nodeRider)
	if nodeRiderEffectOnRider then
		local sEffectRiderNameOnRider = getMountOrRiderValueFromEffectNode(nodeRiderEffectOnRider)
		local nodeRiderOfEffectRiderOnRider = getMountOrRiderCombatTrackerNode(sEffectRiderNameOnRider)
		if hasMount(nodeRiderOfEffectRiderOnRider, sRiderName) then
			local sMsg = string.format("'%s' is a mount and can't mount another.", sRiderName)
			displayChatMessage(sMsg, not checkClientChat())
			return
		end
	end

	local nodeRiderEffect = getRiderEffectNode(nodeMount)
	if nodeRiderEffect then
		-- Check rider validity.
		local sEffectRiderName = getMountOrRiderValueFromEffectNode(nodeRiderEffect)
		local nodeRiderOfEffectMount = getMountOrRiderCombatTrackerNode(sEffectRiderName)
		if hasMount(nodeRiderOfEffectMount, sMountName) then
			local sMsg = string.format("The mount (%s) already has a rider (%s).", sMountName, sEffectRiderName)
			displayChatMessage(sMsg, not checkClientChat())
			return
		end
	end

	if isTrap(nodeRider) or isTrap(nodeMount) then
		displayChatMessage("Traps cannot mount or be mounted.", not checkClientChat())
		return
	end

	-- Check to make sure the rider doesn't have an effect/condition that would make speed zero or unable to do anything.
	local sCondition = getActorDebilitatingCondition(nodeRider)
	if sCondition then
		displayDebilitatingConditionChatMessage(nodeRider, sCondition)
		return
	end

	local sSizeRider = getSize(nodeRider)
	local sSizeMount = getSize(nodeMount)
	if checkEnforceSizeRule() then
		if not sSizeRider or sSizeRider == "" or not sSizeMount or sSizeMount == "" then
			local sMsg = string.format("The rider (%s) and mount (%s) must have a size set.", sRiderName, sMountName)
			displayChatMessage(sMsg, not checkClientChat())
			return
		elseif not isMountLargerThanRider(sSizeMount, sSizeRider) then
			local sMsg = string.format("The mount (%s, %s) has to be at least one size larger than the rider (%s, %s).", sMountName, sSizeMount, sRiderName, sSizeRider)
			displayChatMessage(sMsg, not checkClientChat())
			return
		end
	end

	-- TODO: Clean up the display statement concatenation with tables.
	-- Uncontrolled options start here.
	local sMountValue = ActorManager.getDisplayName(nodeMount)
	local sSemicolonUncontrolled = "; Uncontrolled"
	if bUncontrolledMount then sMountValue = sMountValue .. sSemicolonUncontrolled end
	setNodeWithEffect(nodeRider, "Mount", sMountValue)
	local sRiderValue = ActorManager.getDisplayName(nodeRider)
	if bUncontrolledMount then sRiderValue = sRiderValue .. sSemicolonUncontrolled end
	setNodeWithEffect(nodeMount, "Rider", sRiderValue)
	local sCoreMountRules = "Mounting a creature can be done once per move and you cannot dismount the creature in the same move. " ..
							"The creature must be within 5'. The mount must be at least one size larger. It takes half your speed to mount a creature. "
	local sRuleDetail = ""
	if bUncontrolledMount then
		if checkVerbosityMax() then
			sRuleDetail = "\r\rIntelligent creatures, such as dragons, act independently. An independent mount retains its place in the initiative order. " ..
							"Bearing a rider puts no restrictions on the actions the mount can take, and it moves and acts as it wishes. It might flee from combat, " ..
							"rush to attack and devour a badly injured foe, or otherwise act against your wishes."
		end
	else
		local nOldInit = DB.getValue(nodeMount, INIT_RESULT, 0)
		local sOldInit = tostring(nOldInit)
		local nNewInit = DB.getValue(nodeRider, INIT_RESULT, 0)
		local sNewInit = tostring(nNewInit)
		if nOldInit ~= nNewInit then
			DB.setValue(nodeMount, INIT_RESULT, "number", nNewInit)
			sCoreMountRules = string.format("Changed the mount (%s) initiative from %s to %s.\r\r%s", ActorManager.getDisplayName(nodeMount), sOldInit, sNewInit, sCoreMountRules)
		else
			sCoreMountRules = string.format("Initiative of mount (%s) was not changed.\r\r%s", ActorManager.getDisplayName(nodeMount), sCoreMountRules)
		end

		if checkVerbosityMax() then
			sRuleDetail = "\r\rThe initiative of a controlled mount changes to match yours when you mount it. It moves as you direct it, " ..
							"and it has only three action options: Dash, Disengage, and Dodge. A controlled mount can move and act even on the turn that you mount it."
		end
	end

	if not checkVerbosityOff() then
		displayChatMessage(sCoreMountRules .. sRuleDetail, not checkClientChat())
	end
end

function processUncontrolledMountChatCommand(_, sParams)
	processMountChatCommand(sParams, true)
end

function setNodeWithEffect(nodeCT, sEffect, sValue)
	if not nodeCT or not sEffect then return end

	if sValue then
		if sEffect:lower() == "rider" then
			if not sValue:match("Uncontrolled") and checkControlledMountSkip() then
				sValue = sValue .. "; SKIPTURN"
			end
		end

		sEffect = sEffect .. ": " .. sValue
		deleteAllMountOrRiderEffects(nodeCT)
	end

	local rEffect = {
		sName = sEffect,
		nInit = 0,
		nDuration = 0,
		nGMOnly = 0
	}

	EffectManager.addEffect("", "", nodeCT, rEffect, true)
end

function validateTableOrNew(aTable)
	if aTable and type(aTable) == "table" then
		return aTable
	else
		return {}
	end
end
