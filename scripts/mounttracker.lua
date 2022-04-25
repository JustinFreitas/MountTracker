EFFECTS = "effects"
INIT_RESULT = "initresult"
LABEL = "label"
MOUNT = "mount"
MOUNT_ACTIONS = " It moves as you direct it, and it has only three action options: Dash, Disengage, and Dodge. If the mount provokes an opportunity attack while you're on it, the attacker can target you or the mount."
MOUNTTRACKER_VERBOSE = "MOUNTTRACKER_VERBOSE"
OFF = "off"
OOB_MSGTYPE_ATTACKFROMMOUNT = "attackfrommount"
SECRET = true
SIZE_HUGE = "Huge"
SIZE_LARGE = "Large"
SIZE_MEDIUM = "Medium"
SIZE_SMALL = "Small"
SIZE_TINY = "Tiny"

USER_ISHOST = false

ActionAttack_onAttack = nil

-- This function is required for all extensions to initialize variables and spit out the copyright and name of the extension as it loads
function onInit()
	USER_ISHOST = User.isHost()

	if USER_ISHOST then
		CombatManager.setCustomTurnStart(onTurnStartEvent)
		OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_ATTACKFROMMOUNT, handleAttackFromMount)

		Comm.registerSlashHandler("mt", processChatCommand) -- a command for status of current CT actor and also for subcommands (i.e. clear).
		Comm.registerSlashHandler("mounttracker", processChatCommand) -- a command for status of current CT actor and also for subcommands (i.e. clear).
		Comm.registerSlashHandler(MOUNT, processMountChatCommand)
		Comm.registerSlashHandler("dismount", processDismountChatCommand)
			-- TODO: This will be the new way of doing things once they deprecate Comm.registerSlashHandler() which is coming soon.
		--ChatManager.registerSlashCommand(MOUNT, processChatCommand)

		-- TODO: If not in combat, don't show the combat information when mounting/dismounting.
		-- TODO: Need an effect add handler so that if Prone is added to a rider or mount then the special rules will display in the chat for notification/review.
		-- Something like:  for _,nodeEffect in pairs(DB.getChildren(nodeActor, EFFECTS)) do
		-- TODO: This is for features on abilities tab but we need it for the effects nodes.
		--local featureNamePath = "charsheet.*.featurelist.*.name"
		--DB.addHandler(featureNamePath, "onAdd", onFeatureNameAddOrUpdate)
		--DB.addHandler(featureNamePath, "onUpdate", onFeatureNameAddOrUpdate)
	end

	-- Register chat commands for both host and client.

	-- Unlike the Custom Turn and Init events above, the dice result handler must be registered on host and client.
	-- On extension init, override the skill, attack (also handles spell attack rolls), and castsave result handlers with ours and call the default when we are done with our work (in the override).
	-- The potential conflict has been mitigated by a chaining technique where we store the current action handler for use in our overridden handler.
	ActionAttack_onAttack = ActionAttack.onAttack
	ActionAttack.onAttack = onRollAttack
	ActionsManager.registerResultHandler("attack", onRollAttack)

	-- TODO: Do we need the CT add handler to check for existing Mount effects with an NPC name in it?  Same with PC names?
end

-- Alphebetical list of functions below (onInit() above was an exception)

function checkVerbosityOff()
	return OptionsManager.isOption(MOUNTTRACKER_VERBOSE, OFF)
end

-- Function that walks the CT nodes and deletes the mount effects from them.
function clearAllMountTrackerDataFromCT()
	-- Walk the CT resetting all names.
	-- NOTE: _ is used as a placeholder in Lua for unused variables (in this case, the key).
	for _, nodeCT in pairs(DB.getChildren(CombatManager.CT_LIST)) do
		deleteAllMountOrRiderEffects(nodeCT)
	end
end

-- Deletes all of the mount or rider effects for a CT node (no expiration warning because this is cleanup and not effect usage causing the deletion).
function deleteAllMountOrRiderEffects(nodeCT)
	if not nodeCT then return end

	for _, nodeEffect in pairs(DB.getChildren(nodeCT, EFFECTS)) do
		if isMountOrRiderEffectNode(nodeEffect) then
			nodeEffect.delete()
		end
	end
end

-- Puts a message in chat that is broadcast to everyone attached to the host (including the host) if bSecret is true, otherwise local only.
function displayChatMessage(sFormattedText, bSecret)
	if not sFormattedText then return end

	local msg = {font = "msgfont", icon = "mount_icon", secret = bSecret, text = sFormattedText}

	-- IMPORTANT NOTE: deliverChatMessage() is a broadcast mechanism, addChatMessage() is local only.
	if bSecret then
		Comm.addChatMessage(msg)
	else
		Comm.deliverChatMessage(msg)
	end
end

function displayDebilitatingConditionChatMessage(vActor, sCondition, bForce)
	if not bForce and checkVerbosityOff() then return end

	local sText = string.format("'%s' is %s, can't mount/dismount.",
								ActorManager.getDisplayName(vActor),
								sCondition)
	displayChatMessage(sText, SECRET)
end

function displayProcessAttackFromMount(rSource, rTarget)
	-- if no source or no roll then exit, skipping StealthTracker processing.
	if not rSource or not rSource.sCTNode or rSource.sCTNode == "" then return end

	if not USER_ISHOST then
		-- For clients notify of an action from mount and then exit.  Host handler will pick up message and run code after this block.
		notifyAttackFromMount(rSource.sCTNode, (rTarget and rTarget.sCTNode) or "")
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

	local nodeTarget = ActorManager.getCTNode(rTarget)
	if nodeTarget then
		if getRiderEffectNode(nodeTarget) or getMountEffectNode(nodeTarget) then
			insertFormattedTextWithSeparatorIfNonEmpty(aOutput, "Target is a mounted combatant pair. If an effect moves your mount against its will while you're on it, you must succeed on a DC 10 Dexterity saving throw or fall off the mount, landing prone in a space within 5 feet of it. If you're knocked prone while mounted, you must make the same saving throw. If your mount is knocked prone, you can use your reaction to dismount it as it falls and land on your feet. Otherwise, you are dismounted and fall prone in a space within 5 feet it.")
		end
	end

	displayTableIfNonEmpty(aOutput)
end

function displayTableIfNonEmpty(aTable, bForce)
	if not bForce and checkVerbosityOff() then return end

	aTable = validateTableOrNew(aTable)
	if #aTable > 0 then
		local sDisplay = table.concat(aTable, "\r")
		displayChatMessage(sDisplay, true)
	end
end

function displayTowerRoll()
	if checkVerbosityOff() then return end

	displayChatMessage("An attack was rolled in the tower.  Attacks should be rolled in the open for proper StealthTracker processing.", USER_ISHOST)
end

function getMountOrRiderNodeInCombatTracker(sActorName)
	for _, nodeCT in pairs(DB.getChildren(CombatManager.CT_LIST)) do
		local rActor = ActorManager.resolveActor(nodeCT)
		if rActor and (rActor.sType == "npc" or rActor.sType == "pc") and rActor.sName:lower() == sActorName:lower() then
			return nodeCT
		end
	end

	return nil
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

function getEffectNode(nodeCT, sEffect)
	if not nodeCT or not sEffect then return nil end

	local aSorted = getOrderedEffectsTableFromCTNode(nodeCT)
	local sEffectPattern = "^%s*" .. sEffect:lower() .. ":[^;]*$" -- "^%s*mount:[^;]*$"
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

function getMountOrRiderValueFromEffectNode(nodeEffect)
	if not nodeEffect then return end

	local sEffectLabel = DB.getValue(nodeEffect, LABEL, "")
	local sExtractedMount

	-- Let's break that effect up into it's components (i.e. tokenize on ;)
	local aEffectComponents = EffectManager.parseEffect(sEffectLabel)

	-- Take the last Mount value found, in case it was manually entered and accidentally duplicated (iterate through all of the components).
	for _, component in ipairs(aEffectComponents) do
		local sMatch = string.match(component, "^%s*Mount:%s*(.+)%s*$") or
					   string.match(component, "^%s*Rider:%s*(.+)%s*$")  -- TODO: Can we tie in an inventory mount somehow?
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

function getSize(nodeActor)
	if not nodeActor then return "" end
	return nodeActor.getChild("size").getText()
end

-- Handler for the message to do an attack from a mount.
function handleAttackFromMount(msgOOB)
	if not msgOOB or not msgOOB.type then return end

	if msgOOB.type == OOB_MSGTYPE_ATTACKFROMMOUNT then
		if not msgOOB.sSourceCTNode or not msgOOB.sTargetCTNode then return end

		local rSource = ActorManager.resolveActor(msgOOB.sSourceCTNode)
		if not rSource then return end

		local rTarget = ActorManager.resolveActor(msgOOB.sTargetCTNode)
		displayProcessAttackFromMount(rSource, rTarget)
	end
end

function insertBlankSeparatorIfNotEmpty(aTable)
	if #aTable > 0 then table.insert(aTable, "") end
end

function insertFormattedTextWithSeparatorIfNonEmpty(aTable, sFormattedText)
	insertBlankSeparatorIfNotEmpty(aTable)
	table.insert(aTable, sFormattedText)
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

	return false
end

-- Function to notify the host of an attack from a mounted combatant.
function notifyAttackFromMount(sSourceCTNode, sTargetCTNode)
	if not sSourceCTNode or not sTargetCTNode then return end

	-- Setup the OOB message object, including the required type.
	local msgOOB = {}
	msgOOB.type = OOB_MSGTYPE_ATTACKFROMMOUNT

	-- Capturing the username allows for the effect to be built so that it can be deleted by the client.
	msgOOB.sSourceCTNode = sSourceCTNode
	msgOOB.sTargetCTNode = sTargetCTNode
	Comm.deliverOOBMessage(msgOOB, "")
end

-- TODO: onAddEffect() - If the Prone effect is added to a mounted combatant pair, show the rider and mount 'knocked prone' rules (currently showing on attack hit).

-- Attack roll handler
function onRollAttack(rSource, rTarget, rRoll)
	ActionAttack_onAttack(rSource, rTarget, rRoll)

	-- When attacks are rolled in the tower, the target is always nil.
	if not rTarget and rRoll.bSecret then
		displayTowerRoll()
	end

	displayProcessAttackFromMount(rSource, rTarget)
end

-- This function is one that the Combat Tracker calls if present at the start of a creatures turn.  Wired up in onInit() for the host only.
function onTurnStartEvent(nodeCurrentCTActor) -- arg is CT node
	local nodeEffect = getMountEffectNode(nodeCurrentCTActor)
	local nodeRider = getRiderEffectNode(nodeCurrentCTActor)
	if nodeEffect then
		local sMountName = getMountOrRiderValueFromEffectNode(nodeEffect)
		local nodeMount = getMountOrRiderNodeInCombatTracker(sMountName)
		local sSpeed = nodeMount.getChild("speed").getText()
		-- TODO: Any mounted combat rules or detail needed on the rider's turn.
		displayChatMessage("This actor is riding a mount. Speed: " .. sSpeed .. MOUNT_ACTIONS, true)
	elseif nodeRider then
		local sSpeed = nodeCurrentCTActor.getChild("speed").getText()
		-- TODO: Any mounted combat rules or detail needed on the mount's turn.
		displayChatMessage("This actor is a mount being ridden. Speed: " .. sSpeed .. MOUNT_ACTIONS, true)
	end

	-- TODO: On each turn, walk the combat list and move any controlled mount in the initiative to it's rider's init.  Only change the value if it would actually change.
	-- TODO: Is the actor someone's mount? Must be NPC or PC.  Has the Rider (PHB term) effect.  Rider can be blank/(unspecified).  Name (toLower) must match a mount effect on exactly one CT actor (or first, but multiple is error condition and should be reported to GM).  Must be Friendly.
	-- TODO: If actor is on a mount, if the mount is uncontrolled, remind the chat that they cannot move independently unless dismounting first.  If it's controlled it can take one of the four actions.
	-- TODO: If the actor is on a mount and it's controlled, remind the chat as such and that movement is DONE
	-- TODO: If the actor is already mounted, he cannot mount again.  DONE
	-- TODO: If the mount has a rider, it cannot get a 2nd.  DONE
	-- TODO: If the actor is on a mount, show their mounted speed (speed of the mount).  DONE
	-- TODO: Works with unidentified?  Yes, works with whatever is in the name field on CT, which is the Non-ID Name field if the actor is unidentified.  DONE

	--[[
While you're mounted, you have two options. You can either control the mount or allow it to act independently. Intelligent creatures, such as dragons, act independently.
You can control a mount only if it has been trained to accept a rider. Domesticated horses, donkeys, and similar creatures are assumed to have such training.
The initiative of a controlled mount changes to match yours when you mount it. It moves as you direct it, and it has only three action options: Dash, Disengage, and Dodge. A controlled mount can move and act even on the turn that you mount it.
An independent mount retains its place in the initiative order. Bearing a rider puts no restrictions on the actions the mount can take, and it moves and acts as it wishes. It might flee from combat, rush to attack and devour a badly injured foe, or otherwise act against your wishes.
In either case, if the mount provokes an opportunity attack while you're on it, the attacker can target you or the mount.
	--]]
end

-- Handler for the 'mt' slash commands in chat.
function processChatCommand(_, sParams)
	-- Only allow administrative subcommands when run on the host/DM system.
	local sFailedSubcommand = processHostOnlySubcommands(sParams)
	if sFailedSubcommand then
		displayChatMessage("Unrecognized subcommand: " .. sFailedSubcommand, true)
	end
end

-- Handler for the 'dismount' slash commands in chat.
function processDismountChatCommand(_, _)  -- TODO: If sParams is populated, dismount that user no matter the CT position.
	local nodeCT = CombatManager.getActiveCT()
	if not nodeCT then return end

	if getRiderEffectNode(nodeCT) then
		displayChatMessage("The current actor is a mount, dismount should occur on the rider's turn.", true)
		return
	end

	local nodeMountEffect = getMountEffectNode(nodeCT)
	if not nodeMountEffect then return end

	local sMountName = getMountOrRiderValueFromEffectNode(nodeMountEffect)
	if not sMountName then return end

	local nodeMount = getMountOrRiderNodeInCombatTracker(sMountName)
	if not nodeMount then return end

	-- Check to make sure the rider doesn't have an effect/condition that would make speed zero or unable to do anything.
	local sCondition = getActorDebilitatingCondition(nodeCT)
	if sCondition then
		displayDebilitatingConditionChatMessage(nodeCT, sCondition)
		return
	end

	expireMountOrRiderEffectOnCTNode(nodeCT)
	expireMountOrRiderEffectOnCTNode(nodeMount)
	-- TODO: Calculate the movement needed w/ getSpeed() but it only works as a number on pcs, string on npc that would need to be parsed (comma separated walk is default with no prefix).
	displayChatMessage("Dismounting a creature can be done once per move and you cannot mount this or another creature in the same move.  It takes half your pc speed to dismount a creature.", true)
end

-- Handler for the 'mount' slash commands in chat.  Needs to handle the uncontrolled subcommand (i.e. /mount uncontrolled [MountName])
-- TODO: Needs to find MountName in the CT (after trim), else chat error message and no modifications.
-- TODO: Needs to find MountName in the CT and put the 'Rider: [PCName]' effect on the mount. If uncontrolled, it needs to be designated as such (i.e. Rider: Tauvek (uncontrolled))
-- TODO: Needs to adjust the initiative if the mount is controlled.
-- TODO: If target mount/npc is intelligent, it's always uncontrolled.
function processMountChatCommand(_, sParams)
	local nodeRider = CombatManager.getActiveCT()
	if not nodeRider then return end

	if getRiderEffectNode(nodeRider) then
		displayChatMessage("The current actor is a mount.", true)
		return
	end

	if getMountEffectNode(nodeRider) then
		displayChatMessage("The current actor already has a mount.", true)
		return
	end

	local sMountName = sParams
	local nodeMount = getMountOrRiderNodeInCombatTracker(sMountName);
	if not sMountName or sMountName == "" or not nodeMount then
		displayChatMessage("The mount name must be specified and match a same faction, npc/pc mount in the Combat Tracker.", true)
		return
	end

	-- TODO: Make condition compound with-- Does an existing PC have the Mount: effect with the same mount name?
	if getRiderEffectNode(nodeMount) then
		displayChatMessage("The mount already has a rider.", true)
		return
	end

	-- TODO: 4) If grappled or have a debilitating condition that makes speed zero, then can't mount/dismount.
	-- Check to make sure the rider doesn't have an effect/condition that would make speed zero or unable to do anything.
	local sCondition = getActorDebilitatingCondition(nodeRider)
	if sCondition then
		displayDebilitatingConditionChatMessage(nodeRider, sCondition)
		return
	end

	local sSizeRider = getSize(nodeRider)
	local sSizeMount = getSize(nodeMount)
	if not sSizeRider or sSizeRider == "" or not sSizeMount or sSizeMount == "" then
		displayChatMessage("The rider and mount must have a size set.", true)
		return
	elseif not isMountLargerThanRider(sSizeMount, sSizeRider) then
		displayChatMessage("The mount has to be at least one size larger than the rider.", true)
		return
	end

	setNodeWithEffect(nodeRider, "Mount", ActorManager.getDisplayName(nodeMount))
	setNodeWithEffect(nodeMount, "Rider", ActorManager.getDisplayName(nodeRider))
	DB.setValue(nodeMount, INIT_RESULT, "number", DB.getValue(nodeRider, INIT_RESULT, 0))
	displayChatMessage("Mounting a creature can be done once per move and you cannot dismount the creature in the same move. " ..
					   "The creature must be within 5'. The mount must be at least one size larger. It takes half your speed to mount a creature. " ..
					   "The initiative of a controlled mount changes to match yours when you mount it. It moves as you direct it, " ..
					   "and it has only three action options: Dash, Disengage, and Dodge. A controlled mount can move and act even on the turn that you mount it.", true)
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

function setNodeWithEffect(nodeCT, sEffect, sValue)
	if not nodeCT or not sEffect then return end

	deleteAllMountOrRiderEffects(nodeCT)
	local rEffect = {
		sName = sEffect .. ": " .. sValue,
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
