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
NONE = "none"
MOUNTTRACKER_FRAME_STYLE = "MOUNTTRACKER_FRAME_STYLE"
MOUNTTRACKER_VERBOSE = "MOUNTTRACKER_VERBOSE"
OFF = "off"
ON = "on"
OOB_MSGTYPE_ATTACKFROMMOUNT = "mt_attackfrommount"
OOB_MSGTYPE_MOUNT = "mt_mount"
OOB_MSGTYPE_DISMOUNT = "mt_dismount"
PARTNER_PATH_FIELD = "mtpartnerpath"
PRONE_RULES = "If an effect moves your mount against its will while you're on it, you must succeed on a DC 10 Dexterity saving throw or fall off the mount, landing prone in a space within 5 feet of it. If you're knocked prone while mounted, you must make the same saving throw. If your mount is knocked prone, you can use your reaction to dismount it as it falls and land on your feet. Otherwise, you are dismounted and fall prone in a space within 5 feet it."
SIZE_GARGANTUAN = "Gargantuan"
SIZE_HUGE = "Huge"
SIZE_LARGE = "Large"
SIZE_MEDIUM = "Medium"
SIZE_SMALL = "Small"
SIZE_TINY = "Tiny"
UCMOUNT = "ucmount"
USER_ISHOST = false

local ActionAttack_onAttack = nil
local CombatManager_onDrop = nil
local CombatManager_requestActivation = nil
local EffectManager_addEffect = nil
local EffectManager_addEffectByTable = nil

-- Helper to safely check if a string is blank, preferring the modern StringManager method.
local function isBlankSafe(s)
    if StringManager.isBlank then
        return StringManager.isBlank(s)
    end
    if type(s) ~= "string" then
        return false
    end
    return (string.gsub(s, "%s+", "") == "")
end

-- Helper to safely get an actor from a node/string, preferring the modern getActor method.
local function getActorSafe(v)
    if ActorManager.getActor then
        return ActorManager.getActor(v)
    end
    return ActorManager.resolveActor(v)
end

-- Helper to safely check for effects, preferring the modern CoreRPG or 5E-specific EffectManager if available.
local function hasEffectSafe(rActor, sEffect, rTarget, bTargetedOnly)
    if EffectManager.hasEffect then
        return EffectManager.hasEffect(rActor, sEffect, rTarget, bTargetedOnly)
    end
    if EffectManager5E and EffectManager5E.hasEffect then
        return EffectManager5E.hasEffect(rActor, sEffect, rTarget, bTargetedOnly)
    end
    return EffectManager.hasEffect(rActor, sEffect)
end

function escapePattern(text)
    if isBlankSafe(text) then return "" end
    return text:gsub("([^%w])", "%%%1")
end

function onInit()
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
    OptionsManager.registerOption2(MOUNTTRACKER_FRAME_STYLE, false, option_header, "option_label_MOUNTTRACKER_FRAME_STYLE", option_entry_cycler,
    { baselabel = "option_val_none_MOUNTTRACKER", baseval = NONE, labels = "option_val_chat_MOUNTTRACKER|option_val_story_MOUNTTRACKER|option_val_whisper_MOUNTTRACKER", values = "chat|story|whisper", default = NONE })

	USER_ISHOST = User.isHost()

	if USER_ISHOST then
		OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_ATTACKFROMMOUNT, handleAttackFromMount)
		OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_MOUNT, handleMount)
		OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_DISMOUNT, handleDismount)

		Comm.registerSlashHandler("mt", processChatCommand) -- a command for status of current CT actor and also for subcommands (i.e. clear).
		Comm.registerSlashHandler("mounttracker", processChatCommand) -- a command for status of current CT actor and also for subcommands (i.e. clear).
		Comm.registerSlashHandler(UCMOUNT, processUncontrolledMountChatCommand)
		Comm.registerSlashHandler(MOUNT, processControlledMountChatCommand)
		Comm.registerSlashHandler("dismount", processDismountChatCommand)
        Comm.registerSlashHandler("subinit", processSubinitChatCommand)
			-- TODO: This will be the new way of doing things once they deprecate Comm.registerSlashHandler() which is coming soon.
		--ChatManager.registerSlashCommand(MOUNT, processChatCommand)

		EffectManager_addEffect = EffectManager.addEffect
		EffectManager.addEffect = addEffect
		EffectManager_addEffectByTable = EffectManager.addEffectByTable
		EffectManager.addEffectByTable = addEffectByTable

		if CombatDropManager then
			CombatManager_onDrop = CombatDropManager.onLegacyDropEvent
			CombatDropManager.onLegacyDropEvent = onDrop
		else
			CombatManager_onDrop = CombatManager.onDrop
			CombatManager.onDrop = onDrop
		end

        CombatManager_requestActivation = CombatManager.requestActivation
        CombatManager.requestActivation = requestActivation
	end

	ActionAttack_onAttack = ActionAttack.onAttack
	ActionAttack.onAttack = onRollAttack
	ActionsManager.registerResultHandler("attack", onRollAttack)
end

-- Tracks the effect table currently being processed so that checkProne fires only once
-- per add, even though FGU funnels addEffect -> addEffectByTable (both of which we hook).
-- On FGC, where addEffect does not funnel through addEffectByTable, the addEffect hook
-- still gets to run the check itself.
local rProneCheckInProgress = nil

function addEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	local nodeEffect
	-- Guard against the double-fire: if the underlying addEffect funnels through our
	-- addEffectByTable hook (FGU/modern CoreRPG), let that hook run checkProne. Otherwise
	-- (FGC) the inner call won't reach addEffectByTable and we run the check here.
	local bAlreadyInProgress = (rProneCheckInProgress == rNewEffect)
	rProneCheckInProgress = rNewEffect
	if EffectManager_addEffect then
		nodeEffect = EffectManager_addEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	end

	if not bAlreadyInProgress and rProneCheckInProgress == rNewEffect then
		-- The addEffectByTable hook did not consume the check (FGC path), so do it here.
		checkProne(nodeCT, rNewEffect)
	end
	rProneCheckInProgress = nil

	return nodeEffect
end

function addEffectByTable(vActor, rEffect)
	local rNewEffect;
	if EffectManager_addEffectByTable then
		rNewEffect = EffectManager_addEffectByTable(vActor, rEffect)
	end

	local nodeCT = ActorManager.getCTNode(vActor);
	if nodeCT then
		checkProne(nodeCT, rEffect)
	end
	-- Signal to a wrapping addEffect call (if any) that the prone check has been handled.
	if rProneCheckInProgress == rEffect then
		rProneCheckInProgress = nil
	end

	return rNewEffect;
end

-- Returns true if the effect's name contains a "Prone" condition tag, parsing it into
-- components so that compound effects (e.g. "Prone; Incapacitated; ...") and conditions
-- added via EffectManager.addCondition are recognized, not just a bare "Prone" effect.
function isProneEffect(rNewEffect)
	if not rNewEffect or isBlankSafe(rNewEffect.sName) then return false end

	local aEffectComponents = EffectManager.parseEffect(rNewEffect.sName)
	for _, component in ipairs(aEffectComponents) do
		if component:match("^%s*(.-)%s*$"):lower() == "prone" then
			return true
		end
	end

	return false
end

function checkProne(nodeCT, rNewEffect)
	if isProneEffect(rNewEffect) then
		local nodeRiderEffect = getRiderEffectNode(nodeCT)
		local nodeMountEffect = getMountEffectNode(nodeCT)
		if (nodeRiderEffect or nodeMountEffect) then
			if nodeRiderEffect then
				local sRider = getMountOrRiderValueFromEffectNode(nodeRiderEffect)
				local nodeRider = resolveMountOrRiderPartnerNode(nodeRiderEffect, sRider)
				if nodeRider then
					local nodeMountEffectOfRider = getMountEffectNode(nodeRider)
					if nodeMountEffectOfRider then
						EffectManager.expireEffect(nodeRider, nodeMountEffectOfRider, 0)
					end
				end

				EffectManager.expireEffect(nodeCT, nodeRiderEffect, 0)
			elseif nodeMountEffect then
				local sMount = getMountOrRiderValueFromEffectNode(nodeMountEffect)
				local nodeMount = resolveMountOrRiderPartnerNode(nodeMountEffect, sMount)
				if nodeMount then
					local nodeRiderEffectOfMount = getRiderEffectNode(nodeMount)
					if nodeRiderEffectOfMount then
						EffectManager.expireEffect(nodeMount, nodeRiderEffectOfMount, 0)
					end
				end

				EffectManager.expireEffect(nodeCT, nodeMountEffect, 0)
			end

			if not checkVerbosityOff() then
				displayChatMessage(PRONE_RULES, shouldDisplayAsSecret(nodeCT))
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
			local nodeMountOfEffectRider = resolveMountOrRiderPartnerNode(nodeMountEffect, sEffectMountName)
			if not hasRider(nodeMountOfEffectRider, ActorManager.getDisplayName(nodeCT)) then
				bInvalid = true
			end
		end

		local nodeRiderEffect = getRiderEffectNode(nodeCT)
		if nodeRiderEffect then
			local sEffectRiderName = getMountOrRiderValueFromEffectNode(nodeRiderEffect)
			local nodeRiderOfEffectMount = resolveMountOrRiderPartnerNode(nodeRiderEffect, sEffectRiderName)
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
		local nodeMountOfEffectRider = resolveMountOrRiderPartnerNode(nodeMountEffect, sEffectMountName)
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
		local nodeRiderOfEffectMount = resolveMountOrRiderPartnerNode(nodeRiderEffect, sEffectRiderName)
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
	if isBlankSafe(sFormattedText) then return end

	local msg = {font = "msgfont", icon = "mount_icon", secret = false, text = sFormattedText, mode = getMode()}  -- secret true shows the cross eye icon, wasting space

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
	displayChatMessage(sText, shouldDisplayAsSecret(vActor))
end

function displayProcessAttackFromMount(rSource, rTarget, rRoll)
	-- if no source or no roll then exit, skipping MountTracker processing.
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
			insertFormattedTextWithSeparatorIfNonEmpty(aOutput, "Attack was made by the mount.  Is it uncontrolled?  A controlled mount can only Dash, Disengage, and Dodge.")
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

	displayTableIfNonEmpty(aOutput, false)
end

function displayTableIfNonEmpty(aTable, bSecret)
	aTable = validateTableOrNew(aTable)
	if #aTable > 0 then
		local sDisplay = table.concat(aTable, "\r")
		displayChatMessage(sDisplay, bSecret)
	end
end

-- Function to expire the last found mount effect in the CT node's effects table.  An explicit expiration is needed because the built-in expiration only works if the coded effect matches a known roll or action type (i.e. ATK:3 will expire on attack roll).
function expireMountOrRiderEffectOnCTNode(nodeCT)
	if not nodeCT then return end

	local aSortedCTNodes = getOrderedEffectsTableFromCTNode(nodeCT)
	if not aSortedCTNodes then return end

	-- Walk the effects and expire any that belong to MountTracker.
	for _, nodeEffect in pairs(aSortedCTNodes) do
		if isMountOrRiderEffectNode(nodeEffect) then
			EffectManager.expireEffect(nodeCT, nodeEffect, 0)
		end
	end
end

function getActorDebilitatingCondition(vActor)
	local rActor = getActorSafe(vActor)
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
		if hasEffectSafe(rActor, sCondition) then return sCondition end
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

	-- Walk the effects in order so that the last one added is taken in case they are stacked.  If a duplicate MountTracker effect is found, remove subsequent ones.
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

function getMode()
    local sFrameStyle = OptionsManager.getOption(MOUNTTRACKER_FRAME_STYLE)
    if sFrameStyle == NONE then
        sFrameStyle = ""
    end

    return sFrameStyle
end

function getMountEffectNode(nodeCT)
	return getEffectNode(nodeCT, MOUNT)
end

function getMountOrRiderCombatTrackerNode(sActorName)
	if isBlankSafe(sActorName) then return nil end

	local sLowerActorName = sActorName:lower()

	-- First pass: Try for an exact match.
	for _, nodeCT in pairs(DB.getChildren(CombatManager.CT_LIST)) do
		local sDisplayName = ActorManager.getDisplayName(nodeCT)
		if sDisplayName and sDisplayName:lower() == sLowerActorName then
			return nodeCT -- Exact match found, return immediately.
		end
	end

	-- Second pass: Prefix match (for chat commands).
	local nodeFound = nil
	local sPattern = "^" .. escapePattern(sLowerActorName)
	for _, nodeCT in pairs(DB.getChildren(CombatManager.CT_LIST)) do
		local sDisplayName = ActorManager.getDisplayName(nodeCT)
		if sDisplayName and string.match(sDisplayName:lower(), sPattern) then
			if not nodeFound then
				nodeFound = nodeCT
			else
				return nil -- Ambiguous match
			end
		end
	end

	return nodeFound
end

-- Reads the partner's CT node path off a hidden field on the Mount/Rider effect node (set by
-- setNodeWithEffect), if present. This is a plain DB field alongside the effect's label, not
-- part of the label text, so it never shows up on the CT's visible effects line. Older effects
-- (created before this was added, or typed by hand) won't have one; callers should fall back to
-- name-based resolution in that case.
function getMountOrRiderPathFromEffectNode(nodeEffect)
	if not nodeEffect then return nil end

	return DB.getValue(nodeEffect, PARTNER_PATH_FIELD, nil)
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

		local rSource = getActorSafe(msgOOB.sSourceCTNode)
		if not rSource then return end

		local rTarget = getActorSafe(msgOOB.sTargetCTNode)
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

	-- Resolve the exact mount node from its path when provided (disambiguates duplicate names);
	-- fall back to name-based resolution inside processMountChatCommand for older clients.
	local nodeMount = nil
	if not isBlankSafe(msgOOB.sTargetCTNodePath) then
		nodeMount = CombatManager.getCTFromNode(msgOOB.sTargetCTNodePath)
	end

	local stringToBoolean = { ["true"] = true, ["false"] = false }
	processMountChatCommand(msgOOB.sTargetCTNode, not stringToBoolean[msgOOB.sControlledBoolean], nil, nodeMount)
end

function handleDismount(msgOOB)
	if not msgOOB or not msgOOB.type or msgOOB.type ~= OOB_MSGTYPE_DISMOUNT then return end

	processDismountChatCommand(msgOOB.sActorName)
end

function hasEffectColonValue(nodeEffect, sEffect, sValue)
	if not nodeEffect or isBlankSafe(sEffect) or isBlankSafe(sValue) then return false end

	local sEffectLabel = DB.getValue(nodeEffect, LABEL, "")
	-- Let's break that effect up into it's components (i.e. tokenize on ;)
	local aEffectComponents = EffectManager.parseEffect(sEffectLabel)

	local sEscapedEffect = escapePattern(sEffect)
	local sEscapedValue = escapePattern(sValue)

	-- Take the last Mount value found, in case it was manually entered and accidentally duplicated (iterate through all of the components).
	for _, component in ipairs(aEffectComponents) do
		if string.match(component, "^%W*" .. sEscapedEffect .. ":%W*" .. sEscapedValue .. "%W*$") then
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
		return not (sMount == SIZE_TINY)
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
	local aEffectComponents = EffectManager.parseEffect(sEffectLabel)

	local bHasMountTrackerTag = false
	local bHasSkipTurnTag = false

	for _, component in ipairs(aEffectComponents) do
		local sTrimmed = component:match("^%s*(.-)%s*$")
		if sTrimmed == "mounttracker" then
			bHasMountTrackerTag = true
		elseif sTrimmed == "skipturn" then
			bHasSkipTurnTag = true
		elseif string.match(sTrimmed, "^mount:[^;]*$") or string.match(sTrimmed, "^rider:[^;]*$") then
			return true
		end
	end

	return bHasMountTrackerTag and bHasSkipTurnTag
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

function notifyMount(sTarget, bUncontrolledMount, sTargetCTNodePath)
	-- Setup the OOB message object, including the required type.
	local msgOOB = {}
	msgOOB.type = OOB_MSGTYPE_MOUNT

	msgOOB.sUsername = User.getUsername()
	msgOOB.sControlledBoolean = tostring(not bUncontrolledMount)
	msgOOB.sTargetCTNode = sTarget -- display name (used for messaging/fallback)
	msgOOB.sTargetCTNodePath = sTargetCTNodePath or "" -- exact node path for disambiguation

	Comm.deliverOOBMessage(msgOOB, "")
end

function onDrop(nodetype, nodename, draginfo)


	local nodeSourceCT = draginfo.getCustomData()
	local nodeTargetCT
	if nodename then
		if CombatDropManager then
			nodeTargetCT = CombatManager.getCTFromNode(nodename.sCTNode)
		else
			nodeTargetCT = CombatManager.getCTFromNode(nodename)
		end

		if nodeSourceCT and nodeTargetCT then
			processMountChatCommand(ActorManager.getDisplayName(nodeTargetCT), Input.isControlPressed(), nodeSourceCT)
		end
	end

    if CombatManager_onDrop then
	    CombatManager_onDrop(nodetype, nodename, draginfo)
    end
end

-- Attack roll handler
function onRollAttack(rSource, rTarget, rRoll)
    if ActionAttack_onAttack then
	    ActionAttack_onAttack(rSource, rTarget, rRoll)
    end
	displayProcessAttackFromMount(rSource, rTarget, rRoll)
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

	-- Dismount can be triggered from either side of the pairing: the clicked/named actor may be
	-- the rider (has a Mount effect) or the mount (has a Rider effect). Resolve both nodes either
	-- way so the same dismount logic applies regardless of which CT entry initiated it.
	local nodeRider, nodeMount
	local nodeMountEffect = getMountEffectNode(nodeCT)
	local nodeRiderEffect = getRiderEffectNode(nodeCT)
	if nodeMountEffect then
		nodeRider = nodeCT
		local sMountName = getMountOrRiderValueFromEffectNode(nodeMountEffect)
		if isBlankSafe(sMountName) then return end
		nodeMount = resolveMountOrRiderPartnerNode(nodeMountEffect, sMountName)
	elseif nodeRiderEffect then
		nodeMount = nodeCT
		local sRiderName = getMountOrRiderValueFromEffectNode(nodeRiderEffect)
		if isBlankSafe(sRiderName) then return end
		nodeRider = resolveMountOrRiderPartnerNode(nodeRiderEffect, sRiderName)
	else
		local sMsg = string.format("The current actor (%s) does not have a mount.", sCurrentActorName)
		displayChatMessage(sMsg, shouldDisplayAsSecret(nodeCT))
		return
	end

	if not nodeRider or not nodeMount then
		-- Unmatched pair, clean up.
		deleteAllMountOrRiderEffects(nodeCT)
		return
	end

	-- Check to make sure the rider doesn't have an effect/condition that would make speed zero or unable to do anything.
	local sCondition = getActorDebilitatingCondition(nodeRider)
	if sCondition then
		displayDebilitatingConditionChatMessage(nodeRider, sCondition)
		return
	end

	expireMountOrRiderEffectOnCTNode(nodeRider)
	expireMountOrRiderEffectOnCTNode(nodeMount)
	if not checkVerbosityOff() then
		-- TODO: Calculate the movement needed w/ getSpeed() but it only works as a number on pcs, string on npc that would need to be parsed (comma separated walk is default with no prefix).
		displayChatMessage("Once during your move, you can mount a creature that is within 5 feet of you or dismount. Doing so costs an amount of movement equal to half your speed.", shouldDisplayAsSecret(nodeRider))
	end
end

-- Chat commands that are for host only
function processHostOnlySubcommands(sSubcommand)
	-- Default/empty subcommand - What does the current CT actor not perceive?
	if isBlankSafe(sSubcommand) then
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

function processMountChatCommand(sMountName, bUncontrolledMount, nodeRiderExplicit, nodeMountExplicit)
	local nodeRider = nodeRiderExplicit
	if not nodeRider then
		nodeRider = CombatManager.getActiveCT()
		if not nodeRider then
			displayChatMessage("Combat is not active, which is required for MountTracker processing.", shouldDisplayAsSecret(nodeRider))
			return
		end
	end

	local sRiderName = ActorManager.getDisplayName(nodeRider)
	-- Prefer the exact node the caller clicked/dropped on (disambiguates duplicate names in the
	-- CT, e.g. two "Warhorse" actors). Fall back to resolving the mount by name for chat commands.
	local nodeMount = nodeMountExplicit or getMountOrRiderCombatTrackerNode(sMountName)
	if nodeRider == nodeMount then
		local sMsg = string.format("The rider and mount (%s) must be unique names.", ActorManager.getDisplayName(nodeRider))
		displayChatMessage(sMsg, shouldDisplayAsSecret(nodeRider))
		return
	end

	if not nodeMount or isBlankSafe(sMountName) then
		displayChatMessage("The mount name must be specified and match an npc/pc mount in the Combat Tracker.", shouldDisplayAsSecret(nodeRider))
		return
	end

	sMountName = ActorManager.getDisplayName(nodeMount)

	local nodeMountEffect = getMountEffectNode(nodeRider)
	if nodeMountEffect then
		-- Check mount validity.
		local sEffectMountName = getMountOrRiderValueFromEffectNode(nodeMountEffect)
		local nodeMountOfEffectRider = resolveMountOrRiderPartnerNode(nodeMountEffect, sEffectMountName)
		if hasRider(nodeMountOfEffectRider, sRiderName) then
			local sMsg = string.format("'%s' already has a mount.", sRiderName)
			displayChatMessage(sMsg, shouldDisplayAsSecret(nodeRider))
			return
		end
	end

	local nodeRiderEffectOnRider = getRiderEffectNode(nodeRider)
	if nodeRiderEffectOnRider then
		local sEffectRiderNameOnRider = getMountOrRiderValueFromEffectNode(nodeRiderEffectOnRider)
		local nodeRiderOfEffectRiderOnRider = resolveMountOrRiderPartnerNode(nodeRiderEffectOnRider, sEffectRiderNameOnRider)
		if hasMount(nodeRiderOfEffectRiderOnRider, sRiderName) then
			local sMsg = string.format("'%s' is a mount and can't mount another.", sRiderName)
			displayChatMessage(sMsg, shouldDisplayAsSecret(nodeMount))
			return
		end
	end

	local nodeRiderEffect = getRiderEffectNode(nodeMount)
	if nodeRiderEffect then
		-- Check rider validity.
		local sEffectRiderName = getMountOrRiderValueFromEffectNode(nodeRiderEffect)
		local nodeRiderOfEffectMount = resolveMountOrRiderPartnerNode(nodeRiderEffect, sEffectRiderName)
		if hasMount(nodeRiderOfEffectMount, sMountName) then
			local sMsg = string.format("The mount (%s) already has a rider (%s).", sMountName, sEffectRiderName)
			displayChatMessage(sMsg, shouldDisplayAsSecret(nodeRider))
			return
		end
	end

	if isTrap(nodeRider) or isTrap(nodeMount) then
		displayChatMessage("Traps cannot mount or be mounted.", shouldDisplayAsSecret(nodeRider))
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
		if isBlankSafe(sSizeRider) or isBlankSafe(sSizeMount) then
			local sMsg = string.format("The rider (%s) and mount (%s) must have a size set.", sRiderName, sMountName)
			displayChatMessage(sMsg, shouldDisplayAsSecret(nodeRider))
			return
		elseif not isMountLargerThanRider(sSizeMount, sSizeRider) then
			local sMsg = string.format("The mount (%s, %s) has to be at least one size larger than the rider (%s, %s).", sMountName, sSizeMount, sRiderName, sSizeRider)
			displayChatMessage(sMsg, shouldDisplayAsSecret(nodeRider))
			return
		end
	end

	-- TODO: Clean up the display statement concatenation with tables.
	-- Uncontrolled options start here.
	local sMountValue = ActorManager.getDisplayName(nodeMount)
	local sSemicolonUncontrolled = "; Uncontrolled"
	if bUncontrolledMount then sMountValue = sMountValue .. sSemicolonUncontrolled end
	setNodeWithEffect(nodeRider, "Mount", sMountValue, nodeMount)
	local sRiderValue = ActorManager.getDisplayName(nodeRider)
	if bUncontrolledMount then sRiderValue = sRiderValue .. sSemicolonUncontrolled end
	setNodeWithEffect(nodeMount, "Rider", sRiderValue, nodeRider)
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
		displayChatMessage(sCoreMountRules .. sRuleDetail, shouldDisplayAsSecret(nodeRider))
	end
end

function processSubinitChatCommand(_, _)
	-- Walk the CT resetting all names.
	for _,nodeCT in pairs(DB.getChildren(CombatManager.CT_LIST)) do
        local sCharacterName = ActorManager.getDisplayName(nodeCT)
        local sRegex = "^" .. sCharacterName .. "'s?.*$"
        local nNodeCTInit = DB.getValue(nodeCT, INIT_RESULT, 0)
        for _,subNodeCT in pairs(DB.getChildren(CombatManager.CT_LIST)) do
            if nodeCT ~= subNodeCT and string.match(ActorManager.getDisplayName(subNodeCT), sRegex) ~= nil then
                DB.setValue(subNodeCT, INIT_RESULT, "number", nNodeCTInit)
            end
        end
	end

    displayChatMessage("Sub-initiatives processed.")
end

function processUncontrolledMountChatCommand(_, sParams)
	processMountChatCommand(sParams, true)
end

function isFriend(vActor)
	return vActor and ActorManager.getFaction(vActor) == "friend"
end

function isNpc(vActor)
	return vActor and ActorManager.getRecordType(vActor) == "npc"
end

function shouldDisplayAsSecret(vActor)
    return not checkClientChat() or (not isFriend(vActor) and isNpc(vActor))
end

-- Resolves the CT node paired with a Mount/Rider effect. Prefers the node path embedded in
-- the effect label (set by setNodeWithEffect) since it's unambiguous even when two CT nodes
-- share a display name; falls back to today's name-based lookup when no path is present (older
-- effects) or the path no longer resolves (paired node removed from the CT).
function resolveMountOrRiderPartnerNode(nodeEffect, sActorName)
	local sPartnerPath = getMountOrRiderPathFromEffectNode(nodeEffect)
	if not isBlankSafe(sPartnerPath) then
		local nodePartner = CombatManager.getCTFromNode(sPartnerPath)
		if nodePartner then
			return nodePartner
		end
	end

	return getMountOrRiderCombatTrackerNode(sActorName)
end

function requestActivation(nodeCurrentCTActor, bSkipBell)
    if CombatManager_requestActivation then
        CombatManager_requestActivation(nodeCurrentCTActor, bSkipBell)
    end

	clearAllMountTrackerDataFromCT(true)
	if checkVerbosityOff() then return end

	local rCurrentActor = getActorSafe(nodeCurrentCTActor)
	local sCurrentActorDisplayName = ActorManager.getDisplayName(nodeCurrentCTActor)
	local nodeMountEffect = getMountEffectNode(nodeCurrentCTActor)
	local nodeRiderEffect = getRiderEffectNode(nodeCurrentCTActor)
	local sMountActions = ""
	if checkVerbosityMax() then sMountActions = MOUNT_ACTIONS end

	if nodeMountEffect then
		local sMountName = getMountOrRiderValueFromEffectNode(nodeMountEffect)
		local nodeMount = resolveMountOrRiderPartnerNode(nodeMountEffect, sMountName)
		if hasRider(nodeMount, sCurrentActorDisplayName) then
			local sSpeed = getSpeed(nodeMount)
			-- Any mounted combat rules or detail needed on the rider's turn.
			local sMsg = string.format("'%s' is riding a mount (%s). Speed: %s%s", sCurrentActorDisplayName, sMountName, sSpeed, sMountActions)
			displayChatMessage(sMsg, shouldDisplayAsSecret(rCurrentActor))
		end

		return
	elseif nodeRiderEffect then
		local sRiderName = getMountOrRiderValueFromEffectNode(nodeRiderEffect)
		local nodeRider = resolveMountOrRiderPartnerNode(nodeRiderEffect, sRiderName)
		if hasMount(nodeRider, sCurrentActorDisplayName) then
			local sSpeed = getSpeed(nodeCurrentCTActor)
			local bHasSkipTurn = getEffectNode(nodeCurrentCTActor, "skipturn", true)
			if not bHasSkipTurn then
				local sMsg = string.format("'%s' is a mount being ridden by '%s'. Speed: %s%s", sCurrentActorDisplayName, sRiderName, sSpeed, sMountActions)
				displayChatMessage(sMsg, shouldDisplayAsSecret(nodeRider))
			end
		end

		return
	end
end

function setNodeWithEffect(nodeCT, sEffect, sValue, nodePartner)
	if not nodeCT or isBlankSafe(sEffect) then return end

	local sLabel = sEffect .. ": " .. sValue
	if sEffect:lower() == "rider" then
		if not sValue:match("Uncontrolled") and checkControlledMountSkip() then
			sLabel = sLabel .. "; SKIPTURN"
		end
	end
	sLabel = sLabel .. "; MountTracker"

	if sValue then
		deleteAllMountOrRiderEffects(nodeCT)
	end

	local rEffect = {
		sName = sLabel,
		nInit = 0,
		nDuration = 0,
		nGMOnly = 0
	}

	EffectManager.addEffect("", "", nodeCT, rEffect, true)

	-- Stash the partner's CT node path in a hidden field on the effect (not part of the visible
	-- label) so later re-validation (e.g. clearAllMountTrackerDataFromCT on every turn activation)
	-- can resolve it unambiguously instead of re-deriving it from display-name text, which breaks
	-- when CT nodes share a name. Look the effect back up by tag rather than trusting whatever
	-- EffectManager.addEffect returns (that's not guaranteed to be the created node in every FGU/
	-- CoreRPG version) -- deleteAllMountOrRiderEffects just cleared any prior Mount/Rider effect
	-- on this node above, so this lookup is guaranteed to find only the one just added.
	if nodePartner and nodePartner.getPath then
		local sPartnerPath = nodePartner.getPath()
		if not isBlankSafe(sPartnerPath) then
			local nodeEffect = getEffectNode(nodeCT, sEffect)
			if nodeEffect then
				DB.setValue(nodeEffect, PARTNER_PATH_FIELD, "string", sPartnerPath)
			end
		end
	end
end

function validateTableOrNew(aTable)
	if aTable and type(aTable) == "table" then
		return aTable
	else
		return {}
	end
end
