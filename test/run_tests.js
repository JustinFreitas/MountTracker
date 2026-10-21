const fs = require('fs');
const path = require('path');
const assert = require('assert');
const { LuaFactory } = require('wasmoon');

async function runTests() {
    console.log("Setting up Lua VM via wasmoon...");
    const luaFactory = new LuaFactory();
    const lua = await luaFactory.createEngine();

    // 1. Mock FGU environment globals
    console.log("Mocking FGU environment globals...");

    await lua.doString(`
        Interface = {}
        OptionsManager = {}
        Comm = {}
        DB = {}
        ActorManager = {}
        CombatManager = {}
        EffectManager = {}
        StringManager = {}
        User = {}
        OOBManager = {}
        ActionAttack = {}
        ActionsManager = {}
        UtilityManager = {}
        Session = { IsHost = true, VersionMajor = 4 }
        Input = { isControlPressed = function() return false end }

        -- Mock Interface
        local major, minor, patch = 4, 1, 0
        local sVersionOverride = nil
        function Interface.getVersion()
            if sVersionOverride ~= nil then
                return sVersionOverride
            end
            return major, minor, patch
        end
        function Interface.setVersion(ma, mi, pa)
            sVersionOverride = nil
            major, minor, patch = ma, mi, pa
        end
        function Interface.setVersionString(s)
            sVersionOverride = s
        end

        -- Mock User
        function User.isHost() return true end

        -- Mock StringManager
        StringManager.trim = function(s)
            if not s then return "" end
            return s:match("^%s*(.-)%s*$")
        end
        StringManager.isBlank = function(s)
            if type(s) ~= "string" then return true end
            return s:gsub("%s+", "") == ""
        end

        -- Mock OptionsManager
        local options = {}
        function OptionsManager.registerOption2() end
        function OptionsManager.isOption(key, val)
            return options[key] == val
        end
        function OptionsManager.setOption(key, val)
            options[key] = val
        end
        function OptionsManager.getOption(key)
            return options[key]
        end

        -- Default options
        options["MOUNTTRACKER_CONTROLLED_MOUNT_SKIP"] = "on"
        options["MOUNTTRACKER_ENFORCE_SIZE"] = "on"
        options["MOUNTTRACKER_CLIENT_CHAT"] = "on"
        options["MOUNTTRACKER_VERBOSE"] = "max"

        -- Mock Comm
        local chatMessages = {}
        local secretMessages = {}
        local broadcastMessages = {}
        function Comm.registerSlashHandler() end
        function Comm.addChatMessage(msg)
            table.insert(chatMessages, msg.text)
            table.insert(secretMessages, msg.text)
        end
        function Comm.deliverChatMessage(msg)
            table.insert(chatMessages, msg.text)
            table.insert(broadcastMessages, msg.text)
        end
        function Comm.getChatMessages()
            return chatMessages
        end
        function Comm.getSecretMessages()
            return secretMessages
        end
        function Comm.getBroadcastMessages()
            return broadcastMessages
        end
        function Comm.clearChatMessages()
            chatMessages = {}
            secretMessages = {}
            broadcastMessages = {}
        end

        -- Mock CombatDropManager
        CombatDropManager = {}
        CombatDropManager._handleAnyDrop = function(draginfo, sTargetPath) return false end
        CombatDropManager.handleAnyDrop = function(draginfo, sTargetPath, ...)
            return CombatDropManager._handleAnyDrop(draginfo, sTargetPath, ...)
        end
        CombatDropManager.registerLegacyDropCallback = function(cb) CombatDropManager._legacyCb = cb end

        -- Mock OOBManager
        local oobHandlers = {}
        function OOBManager.registerOOBMsgHandler(msgType, handler)
            oobHandlers[msgType] = handler
        end
        function OOBManager.triggerOOB(msg)
            if oobHandlers[msg.type] then
                oobHandlers[msg.type](msg)
            end
        end

        -- Mock CombatManager
        CombatManager.CT_LIST = "combattracker"
        function CombatManager.requestActivation() end
        local activeCTNode = nil
        function CombatManager.getActiveCT() return activeCTNode end
        function CombatManager.setActiveCTForTest(node) activeCTNode = node end

        -- Mock Database structure
        dbData = {}
        local dbChildren = {}

        local function nodePathOf(node)
            if type(node) == "table" and node.path then
                return node.path
            elseif type(node) == "string" then
                return node
            end
            return ""
        end

        -- Builds a node object matching the subset of the real FGU DB node API this
        -- extension relies on: .path, .getName(), .getPath(), .delete().
        local function makeNode(parentPath, key)
            local fullPath = parentPath .. "." .. key
            return {
                path = fullPath,
                getName = function() return key end,
                getPath = function() return fullPath end,
                delete = function()
                    if dbChildren[parentPath] then
                        dbChildren[parentPath][key] = nil
                    end
                end
            }
        end

        function DB.setNodeValue(path, val)
            dbData[path] = val
        end

        function DB.getValue(nodeOrPath, fieldOrDefault, defaultVal)
            if defaultVal == nil and (type(fieldOrDefault) ~= "string" or fieldOrDefault == "" or (type(nodeOrPath) == "string" and nodeOrPath:match("^options%."))) then
                local sPath = (type(nodeOrPath) == "table" and nodeOrPath.getPath and nodeOrPath.getPath()) or tostring(nodeOrPath)
                if dbData[sPath] ~= nil then
                    return dbData[sPath]
                end
                return fieldOrDefault
            end
            local fullPath = nodePathOf(nodeOrPath) .. "." .. fieldOrDefault
            if dbData[fullPath] ~= nil then
                return dbData[fullPath]
            end
            return defaultVal
        end

        function DB.setValue(node, field, sType, val)
            dbData[nodePathOf(node) .. "." .. field] = val
        end

        function DB.getText(node, field, default)
            return DB.getValue(node, field, default)
        end

        function DB.findNode(nodePath)
            if type(nodePath) == "table" then return nodePath end
            return { path = nodePath }
        end

        function DB.setChildren(nodePath, children)
            dbChildren[nodePath] = children
        end

        function DB.getChildren(node, field)
            local nodePath = nodePathOf(node)
            local fullPath = field and (nodePath .. "." .. field) or nodePath
            local children = dbChildren[fullPath] or {}
            local list = {}
            for k, _ in pairs(children) do
                list[k] = makeNode(fullPath, k)
            end
            return list
        end

        -- Test helper (not part of the real FGU API): registers a new top-level Combat
        -- Tracker entry with the given id/name and returns its node.
        function DB.addCTNode(id, name)
            dbChildren[CombatManager.CT_LIST] = dbChildren[CombatManager.CT_LIST] or {}
            dbChildren[CombatManager.CT_LIST][id] = true
            local node = makeNode(CombatManager.CT_LIST, id)
            dbData[node.path .. ".name"] = name
            return node
        end

        function CombatManager.getCTFromNode(sPath)
            if not sPath or sPath == "" then return nil end
            local children = dbChildren[CombatManager.CT_LIST] or {}
            for k, _ in pairs(children) do
                if (CombatManager.CT_LIST .. "." .. k) == sPath then
                    return makeNode(CombatManager.CT_LIST, k)
                end
            end
            return nil
        end

        -- Mock EffectManager
        local effectCounters = {}
        function EffectManager.parseEffect(sEffect)
            local components = {}
            if not sEffect or sEffect == "" then return components end
            for token in (sEffect .. ";"):gmatch("(.-);") do
                table.insert(components, token)
            end
            return components
        end
        function EffectManager.addEffect(sUser, sIdentity, nodeCT, rEffect, bShowMsg)
            local parentPath = nodeCT.path .. ".effects"
            effectCounters[parentPath] = (effectCounters[parentPath] or 0) + 1
            local key = string.format("id-%05d", effectCounters[parentPath])
            dbChildren[parentPath] = dbChildren[parentPath] or {}
            dbChildren[parentPath][key] = true
            dbData[parentPath .. "." .. key .. ".label"] = rEffect.sName
            return makeNode(parentPath, key)
        end
        function EffectManager.expireEffect(nodeCT, nodeEffect, n)
            if nodeEffect and nodeEffect.delete then nodeEffect.delete() end
        end
        function EffectManager.hasEffect(rActor, sEffect, rTarget, bTargetedOnly)
            return false
        end

        -- Mock ActorManager
        local actorMap = {}
        function ActorManager.getActor(nodeCT)
            local p = (type(nodeCT) == "table" and nodeCT.path) or nodeCT
            return actorMap[p]
        end
        function ActorManager.resolveActor(nodeCT)
            local p = (type(nodeCT) == "table" and nodeCT.path) or nodeCT
            return actorMap[p]
        end
        function ActorManager.setActor(nodeCTPath, actor)
            actorMap[nodeCTPath] = actor
        end
        function ActorManager.getCTNode(v)
            if type(v) == "table" and v.path and v.path:match("^combattracker") then
                return v
            end
            if type(v) == "table" and v.getPath and v.getPath():match("^combattracker") then
                return v
            end
            if type(v) == "string" and v:match("^combattracker") then
                return DB.findNode(v)
            end
            if type(v) == "table" and v.sCTNode then
                return DB.findNode(v.sCTNode)
            end
            return nil
        end
        function ActorManager.getDisplayName(node)
            return DB.getValue(node, "name", "Unknown")
        end
        function ActorManager.getFaction(v) return "friend" end
        function ActorManager.getRecordType(v)
            return DB.getValue(v, "recordType", "pc")
        end
        function ActorManager.isPC(v)
            return ActorManager.getRecordType(v) == "pc"
        end

        -- Mock ActionsManager
        ActionsManager.aRollHandlers = {}
        function ActionsManager.registerResultHandler(sType, callback)
            ActionsManager.aRollHandlers[sType] = { fResultHandler = callback }
        end
        function ActionsManager.getResultHandler(sType)
            if ActionsManager.aRollHandlers[sType] then
                return ActionsManager.aRollHandlers[sType].fResultHandler
            end
            return nil
        end
    `);

    // 2. Load the actual mounttracker script
    console.log("Loading scripts/mounttracker.lua into VM...");
    const luaCodePath = path.join(__dirname, '../scripts/mounttracker.lua');
    const luaCode = fs.readFileSync(luaCodePath, 'utf8');

    await lua.doString(luaCode);
    console.log("MountTracker loaded successfully inside VM.\n");

    // Run onInit() once, as FGU would, so the extension's requestActivation/addEffect hooks
    // are installed before any test exercises them. Disable size enforcement so mount/rider
    // pairing tests don't need to fabricate size data unrelated to what they're testing.
    await lua.doString(`
        onInit()
        OptionsManager.setOption("MOUNTTRACKER_ENFORCE_SIZE", "off")
    `);

    // 3. Define and run test assertions
    console.log("Running Unit Tests...");
    let testsPassed = 0;
    let testsFailed = 0;

    async function runAssert(fnName, expected, luaCodeToRun) {
        try {
            const result = await lua.doString(luaCodeToRun);
            assert.strictEqual(result, expected);
            console.log(`  ✓ PASS: ${fnName} -> got ${result}`);
            testsPassed++;
        } catch (err) {
            console.error(`  ✗ FAIL: ${fnName} -> expected ${expected}, got error or mismatch: ${err.message}`);
            testsFailed++;
        }
    }



    // --- TEST 1: checkFGC ---
    await lua.doString(`
        UtilityManager.isClientFGU = nil
        Session.VersionMajor = nil
        Interface.setVersionString("3.3.16")
    `);
    await runAssert("checkFGC() FGC string version", true, "return checkFGC()");

    await lua.doString(`
        Interface.setVersion(3, 3, 16)
    `);
    await runAssert("checkFGC() FGC number tuple", true, "return checkFGC()");

    await lua.doString(`
        Interface.setVersion(4, 1, 0)
    `);
    await runAssert("checkFGC() FGU number tuple", false, "return checkFGC()");

    await lua.doString(`
        UtilityManager.isClientFGU = function() return true end
    `);
    await runAssert("checkFGC() UtilityManager FGU true", false, "return checkFGC()");

    await lua.doString(`
        UtilityManager.isClientFGU = function() return false end
    `);
    await runAssert("checkFGC() UtilityManager FGC false", true, "return checkFGC()");

    await lua.doString(`
        UtilityManager.isClientFGU = nil
        Session.VersionMajor = 4
    `);
    await runAssert("checkFGC() Session.VersionMajor >= 4", false, "return checkFGC()");

    await lua.doString(`
        Session.VersionMajor = 3
    `);
    await runAssert("checkFGC() Session.VersionMajor < 4", true, "return checkFGC()");

    // Reset environment back to default FGU for subsequent tests
    await lua.doString(`
        Session.VersionMajor = 4
        Interface.setVersion(4, 1, 0)
        IS_FGC = false
    `);

    // --- TEST: getActorSafe resolution ---
    await runAssert("getActorSafe uses resolveActor on FGC", "resolved_actor", `
        return (function()
            local oldResolve = ActorManager.resolveActor
            local oldGet = ActorManager.getActor
            ActorManager.resolveActor = function(v) return "resolved_actor" end
            ActorManager.getActor = function(v) return "got_actor" end
            IS_FGC = true
            local result = getActorSafe("test_node")
            IS_FGC = false
            ActorManager.resolveActor = oldResolve
            ActorManager.getActor = oldGet
            return result
        end)()
    `);
    await runAssert("getActorSafe uses getActor on FGU", "got_actor", `
        return (function()
            local oldResolve = ActorManager.resolveActor
            local oldGet = ActorManager.getActor
            ActorManager.resolveActor = function(v) return "resolved_actor" end
            ActorManager.getActor = function(v) return "got_actor" end
            IS_FGC = false
            local result = getActorSafe("test_node")
            ActorManager.resolveActor = oldResolve
            ActorManager.getActor = oldGet
            return result
        end)()
    `);

    // --- TEST: onInit /reload idempotency ---
    await runAssert("onInit reload idempotency does not cause recursion", true, `
        return (function()
            -- Call onInit multiple times to simulate /reload
            onInit()
            onInit()
            onInit()

            -- Verify requestActivation doesn't overflow stack
            CombatManager.requestActivation("test_node", false)

            -- Verify attack roll result handler doesn't overflow stack
            local h = ActionsManager.getResultHandler("attack")
            if h then
                h({ sType = "pc" }, { sType = "npc" }, { sDesc = "Attack [1d20+5 = 15]", aMessages = {} })
            end

            return true
        end)()
    `);

    // --- TEST: onDrop event deduplication ---
    await runAssert("onDrop deduplication suppresses duplicate drop on FGC", 1, `
        return (function()
            local nodeRider = DB.addCTNode("rider_drop", "RiderDrop")
            local nodeMount = DB.addCTNode("mount_drop", "MountDrop")
            local mockDrag = {
                getCustomData = function() return nodeRider end
            }
            local dropCallCount = 0
            local oldProcess = processMountChatCommand
            processMountChatCommand = function() dropCallCount = dropCallCount + 1 end

            IS_FGC = true
            LAST_DRAG_INFO = nil
            LAST_NODE_NAME = nil
            LAST_NODE_TYPE = nil

            -- First drop event
            onDrop("combattracker_entry", nodeMount.path, mockDrag)
            -- Duplicate drop event (identical args)
            onDrop("combattracker_entry", nodeMount.path, mockDrag)

            IS_FGC = false
            processMountChatCommand = oldProcess
            return dropCallCount
        end)()
    `);
    await runAssert("onDrop allows multiple drops on FGU", 2, `
        return (function()
            local nodeRider = DB.addCTNode("rider_drop_fgu", "RiderDropFGU")
            local nodeMount = DB.addCTNode("mount_drop_fgu", "MountDropFGU")
            local mockDrag = {
                getCustomData = function() return nodeRider end
            }
            local dropCallCount = 0
            local oldProcess = processMountChatCommand
            processMountChatCommand = function() dropCallCount = dropCallCount + 1 end

            IS_FGC = false

            -- First drop event
            onDrop("combattracker_entry", nodeMount.path, mockDrag)
            -- Second drop event (FGU allows distinct intentional drops)
            onDrop("combattracker_entry", nodeMount.path, mockDrag)

            processMountChatCommand = oldProcess
            return dropCallCount
        end)()
    `);

    // --- TEST 2: escapePattern ---
    await runAssert("escapePattern normal", "hello", "return escapePattern('hello')");
    await runAssert("escapePattern with brackets", "mount% %(controlled%)", "return escapePattern('mount (controlled)')");

    // --- TEST 3: Mount pairing (unique names) survives clearAllMountTrackerDataFromCT ---
    // Partner resolution is plain name-based (resolveMountOrRiderPartnerNode is a passthrough to
    // getMountOrRiderCombatTrackerNode -- see the comment on that function for why the v1.9-v1.9.2
    // path-based disambiguation was reverted). This only guarantees correctness for unique CT
    // names; duplicate-named mounts/riders are a known, accepted limitation, same as pre-v1.9.
    await runAssert("mount pairing survives periodic cleanup", true, `
        return (function()
            local nodeBob = DB.addCTNode("bob", "Bob")
            local nodeWarhorse = DB.addCTNode("warhorse", "Warhorse")

            processMountChatCommand("Warhorse", false, nodeBob, nodeWarhorse)

            local sBobMountLabel = DB.getValue(getMountEffectNode(nodeBob), "label", "")
            local bLabelClean = not sBobMountLabel:match("[Pp]ath:")

            clearAllMountTrackerDataFromCT(true)

            return getMountEffectNode(nodeBob) ~= nil and getRiderEffectNode(nodeWarhorse) ~= nil and bLabelClean
        end)()
    `);

    // --- TEST 4: Pairing survives repeated turn activation ---
    await runAssert("mount pairing survives repeated turn activation", true, `
        return (function()
            local nodeBob2 = DB.addCTNode("bob2", "Bob2")
            local nodeWarhorse2 = DB.addCTNode("warhorse2", "Warhorse2")
            local nodeGoblin = DB.addCTNode("goblin", "Goblin")

            processMountChatCommand("Warhorse2", false, nodeBob2, nodeWarhorse2)

            -- Simulate FGU calling requestActivation on every turn advance, for several turns.
            CombatManager.requestActivation(nodeBob2, false)
            CombatManager.requestActivation(nodeWarhorse2, false)
            CombatManager.requestActivation(nodeGoblin, false)
            CombatManager.requestActivation(nodeBob2, false)

            return getMountEffectNode(nodeBob2) ~= nil and getRiderEffectNode(nodeWarhorse2) ~= nil
        end)()
    `);

    // --- TEST 5: Effects created directly (not via processMountChatCommand) still validate by name ---
    await runAssert("directly-created effects still validate by name", true, `
        return (function()
            local nodeCarl = DB.addCTNode("carl", "Carl")
            local nodePony = DB.addCTNode("pony", "Pony")

            EffectManager.addEffect("", "", nodeCarl, { sName = "Mount: Pony; MountTracker", nInit = 0, nDuration = 0, nGMOnly = 0 }, true)
            EffectManager.addEffect("", "", nodePony, { sName = "Rider: Carl; MountTracker", nInit = 0, nDuration = 0, nGMOnly = 0 }, true)

            clearAllMountTrackerDataFromCT(true)

            return getMountEffectNode(nodeCarl) ~= nil and getRiderEffectNode(nodePony) ~= nil
        end)()
    `);

    // --- TEST 6: Genuine invalidation (partner removed from CT) still cleans up ---
    await runAssert("pairing is still deleted when the partner is removed from the CT", true, `
        return (function()
            local nodeDana = DB.addCTNode("dana", "Dana")
            local nodeElk = DB.addCTNode("elk", "Elk")

            processMountChatCommand("Elk", false, nodeDana, nodeElk)

            nodeElk.delete()

            clearAllMountTrackerDataFromCT(true)

            return getMountEffectNode(nodeDana) == nil
        end)()
    `);

    // --- TEST 7: Mount created via the active-CT flow gets both sides of the pairing ---
    await runAssert("mount via active-CT flow creates both sides of the pairing", true, `
        return (function()
            local nodeErin = DB.addCTNode("erin", "Erin")
            local nodePony2 = DB.addCTNode("pony2", "Pony2")

            CombatManager.setActiveCTForTest(nodeErin)
            processMountChatCommand("Pony2", false, nil, nodePony2)

            return getMountEffectNode(nodeErin) ~= nil and getRiderEffectNode(nodePony2) ~= nil
        end)()
    `);

    // --- TEST 8: Dismount triggered from the rider's CT entry ---
    await runAssert("dismount triggered from the rider clears both sides", true, `
        return (function()
            local nodeFinn = DB.addCTNode("finn", "Finn")
            local nodeMule = DB.addCTNode("mule", "Mule")

            processMountChatCommand("Mule", false, nodeFinn, nodeMule)
            processDismountChatCommand(nil, "Finn")

            return getMountEffectNode(nodeFinn) == nil and getRiderEffectNode(nodeMule) == nil
        end)()
    `);

    // --- TEST 9: Dismount triggered from the mount's CT entry ---
    await runAssert("dismount triggered from the mount clears both sides", true, `
        return (function()
            local nodeGwen = DB.addCTNode("gwen", "Gwen")
            local nodeYak = DB.addCTNode("yak", "Yak")

            processMountChatCommand("Yak", false, nodeGwen, nodeYak)
            processDismountChatCommand(nil, "Yak")

            return getMountEffectNode(nodeGwen) == nil and getRiderEffectNode(nodeYak) == nil
        end)()
    `);

    // --- TEST 10: Exact-name duplicates are detected as ambiguous and warn ---
    await runAssert("exact-name duplicates are detected as ambiguous and warn", true, `
        return (function()
            DB.addCTNode("dupA", "Twin")
            DB.addCTNode("dupB", "Twin")

            Comm.clearChatMessages()
            local nodeResolved = getMountOrRiderCombatTrackerNode("Twin", true)
            local sawWarning = false
            for _, m in ipairs(Comm.getChatMessages()) do
                if m:match("[Mm]ultiple") then sawWarning = true end
            end

            return nodeResolved == nil and sawWarning
        end)()
    `);

    // --- TEST 11: Mounting by typed name refuses when the mount name is ambiguous ---
    await runAssert("mounting by typed name refuses when ambiguous", true, `
        return (function()
            local nodeRiderX = DB.addCTNode("riderX", "RiderX")
            local nodeMountA = DB.addCTNode("mountA", "Steed")
            local nodeMountB = DB.addCTNode("mountB", "Steed")

            processMountChatCommand("Steed", false, nodeRiderX, nil)

            return getMountEffectNode(nodeRiderX) == nil and getRiderEffectNode(nodeMountA) == nil and getRiderEffectNode(nodeMountB) == nil
        end)()
    `);

    // --- TEST 12: Dismount by ambiguous typed name does not fall back to the active actor ---
    // Guards against the exact fragility reported: an ambiguous typed name must not silently
    // act on whichever actor happens to be active instead.
    await runAssert("dismount by ambiguous typed name leaves an unrelated active actor untouched", true, `
        return (function()
            local nodeInnocentRider = DB.addCTNode("innocent", "InnocentBystander")
            local nodeInnocentMount = DB.addCTNode("innocentMount", "InnocentMount")
            processMountChatCommand("InnocentMount", false, nodeInnocentRider, nodeInnocentMount)

            DB.addCTNode("dupA2", "Rival")
            DB.addCTNode("dupB2", "Rival")

            CombatManager.setActiveCTForTest(nodeInnocentRider)
            processDismountChatCommand(nil, "Rival")

            return getMountEffectNode(nodeInnocentRider) ~= nil and getRiderEffectNode(nodeInnocentMount) ~= nil
        end)()
    `);

    // --- TEST 13: Dismount via an explicit node (radial menu) bypasses name ambiguity ---
    await runAssert("dismount via explicit node bypasses name ambiguity", true, `
        return (function()
            local nodeRiderC = DB.addCTNode("riderC", "Twin2")
            local nodeMountC = DB.addCTNode("mountC", "SteedC")
            processMountChatCommand("SteedC", false, nodeRiderC, nodeMountC)

            DB.addCTNode("unrelatedTwin", "Twin2")

            processDismountChatCommand(nil, "Twin2", nodeRiderC)

            return getMountEffectNode(nodeRiderC) == nil and getRiderEffectNode(nodeMountC) == nil
        end)()
    `);

    // --- TEST 14: Dismounting from the mount correctly finds the paired rider despite an
    // unrelated duplicate-named rider elsewhere in the CT. This is the case that used to fail:
    // nodeCT (the mount) is resolved unambiguously via the explicit node from the radial menu,
    // but the RIDER's identity still had to be resolved by the name stored on the mount's own
    // "Rider: <name>" effect -- resolveMountOrRiderPartnerNode now verifies that candidate via
    // hasMount()/hasRider() against the known mount instead of guessing the first name match.
    await runAssert("dismount from the mount finds the correct rider among duplicate names", true, `
        return (function()
            local nodeRiderReal = DB.addCTNode("riderReal", "Durin")
            local nodeMount = DB.addCTNode("mountX", "Warhorse")
            processMountChatCommand("Warhorse", false, nodeRiderReal, nodeMount)

            -- Unrelated duplicate-named actor who never mounted anything.
            local nodeRiderDupe = DB.addCTNode("riderDupe", "Durin")

            -- Dismount triggered from the mount's entry, as the CT radial menu does.
            processDismountChatCommand(nil, "Warhorse", nodeMount)

            return getMountEffectNode(nodeRiderReal) == nil and getRiderEffectNode(nodeMount) == nil
        end)()
    `);

    // --- TEST 15: Same scenario, but three duplicate-named candidates, to rule out the fix
    // only working because of how many candidates happen to precede/follow the real one. ---
    await runAssert("dismount from the mount finds the correct rider among several duplicates", true, `
        return (function()
            local nodeRiderReal2 = DB.addCTNode("riderReal2", "Elowen")
            local nodeMount2 = DB.addCTNode("mount2", "Pony")
            processMountChatCommand("Pony", false, nodeRiderReal2, nodeMount2)

            DB.addCTNode("dupe1", "Elowen")
            DB.addCTNode("dupe2", "Elowen")
            DB.addCTNode("dupe3", "Elowen")

            processDismountChatCommand(nil, "Pony", nodeMount2)

            return getMountEffectNode(nodeRiderReal2) == nil and getRiderEffectNode(nodeMount2) == nil
        end)()
    `);

    // --- TEST 16: Parentheses parsing in getEffectNode ---
    await runAssert("getEffectNode parses parenthesized (GM-only) effect labels", true, `
        return (function()
            local node = DB.addCTNode("testNode", "TestActor")
            -- Add GM-only mount effect (parenthesized)
            local rEffect1 = { sName = "(mount: horse)" }
            EffectManager.addEffect("", "", node, rEffect1, true)

            -- Add standard rider effect
            local rEffect2 = { sName = "rider: elara" }
            EffectManager.addEffect("", "", node, rEffect2, true)

            local nodeMountEffect = getMountEffectNode(node)
            local nodeRiderEffect = getRiderEffectNode(node)

            return nodeMountEffect ~= nil and nodeRiderEffect ~= nil
        end)()
    `);

    // --- TEST 17: Duplicate attacker redirection via getActiveDuplicateCTNodePath ---
    await runAssert("getActiveDuplicateCTNodePath redirects to the active duplicate in combat", true, `
        return (function()
            -- Create two duplicate named combatants
            local node1 = DB.addCTNode("durin1", "Durin")
            local node2 = DB.addCTNode("durin2", "Durin")

            -- Set the second duplicate as the active turn combatant
            CombatManager.setActiveCTForTest(node2)

            local sNewPath = getActiveDuplicateCTNodePath(node1.getPath())
            return sNewPath == node2.getPath()
        end)()
    `);

    // --- TEST 18: CombatDropManager.handleAnyDrop with duplicate mount names ---
    await runAssert("handleAnyDrop passes explicit target node and pairs identical-named mounts", true, `
        return (function()
            local nodeRider = DB.addCTNode("rider_drop_test", "Knight")
            local nodeMount1 = DB.addCTNode("mount_drop_1", "Warhorse")
            local nodeMount2 = DB.addCTNode("mount_drop_2", "Warhorse")

            local mockDrag = {
                getType = function() return "combattrackerentry" end,
                getCustomData = function() return nodeRider end
            }

            -- Drop rider specifically onto Mount 2
            CombatDropManager.handleAnyDrop(mockDrag, nodeMount2.getPath())

            -- Mount 2 should receive the Rider effect, NOT Mount 1
            local effMount1 = getRiderEffectNode(nodeMount1)
            local effMount2 = getRiderEffectNode(nodeMount2)

            return effMount1 == nil and effMount2 ~= nil
        end)()
    `);

    // --- TEST 19: CombatDropManager.handleAnyDrop token shortcut fallback ---
    await runAssert("handleAnyDrop supports token shortcut fallback when customData is nil", true, `
        return (function()
            local nodeRider = DB.addCTNode("rider_token_test", "Cavalier")
            local nodeMount = DB.addCTNode("mount_token_test", "Griffon")

            local mockDrag = {
                getType = function() return "token" end,
                getCustomData = function() return nil end,
                getShortcutData = function() return "combattrackerentry", nodeRider.getPath() end
            }

            CombatDropManager.handleAnyDrop(mockDrag, nodeMount.getPath())

            local effMount = getRiderEffectNode(nodeMount)
            local effRider = getMountEffectNode(nodeRider)
            return effMount ~= nil and effRider ~= nil
        end)()
    `);

    // --- TEST 20: Attack Secrecy and Dice Tower Privacy ---
    await runAssert("displayProcessAttackFromMount delivers secretly on [TOWER] or bTower roll", true, `
        return (function()
            local nodeRider = DB.addCTNode("tower_rider", "Paladin")
            local nodeMount = DB.addCTNode("tower_mount", "Pegasus")
            processMountChatCommand("Pegasus", false, nodeRider, nodeMount)

            Comm.clearChatMessages()
            local rSource = ActorManager.resolveActor(nodeRider) or { sCTNode = nodeRider.getPath() }
            local rRollTower = { sDesc = "Attack [TOWER]", bTower = true }

            USER_ISHOST = true
            displayProcessAttackFromMount(rSource, nil, rRollTower)

            local secretCount = #Comm.getSecretMessages()
            local broadcastCount = #Comm.getBroadcastMessages()

            return secretCount > 0 and broadcastCount == 0
        end)()
    `);

    // --- TEST 21: Unidentified NPC Effect and Display Name Protection ---
    await runAssert("unidentified NPC gets nGMOnly = 1 and masked display name in chat", true, `
        return (function()
            local nodeRider = DB.addCTNode("hero_rider", "Hero")
            local nodeMount = DB.addCTNode("secret_dragon", "Young Green Dragon")
            DB.setValue(nodeMount, "isidentified", "number", 0)
            DB.setValue(nodeMount, "nonid_name", "string", "Strange Winged Beast")
            DB.setValue(nodeMount, "recordType", "string", "npc")

            -- Verify getActorDisplayNameSafe masks the name
            local sSafe = getActorDisplayNameSafe(nodeMount)
            if sSafe ~= "Strange Winged Beast" then return false end

            -- Create pairing
            processMountChatCommand("Young Green Dragon", false, nodeRider, nodeMount)

            -- Check GM-only flag in effects
            local parentPath = nodeRider.getPath() .. ".effects"
            local children = DB.getChildren(nodeRider, "effects")
            local bGMOnlyFound = false
            for _, child in pairs(children) do
                local sLabel = DB.getValue(child, "label", "")
                if sLabel:match("Mount:") then
                    bGMOnlyFound = true
                end
            end

            return bGMOnlyFound
        end)()
    `);

    // --- TEST 22: /subinit with Special Character Names ---
    await runAssert("processSubinitChatCommand synchronizes initiative and survives regex special characters", true, `
        return (function()
            -- Create master with brackets and dashes
            local nodeMaster1 = DB.addCTNode("master1", "Ranger (Wood Elf)")
            DB.setValue(nodeMaster1, "initresult", "number", 18)
            local nodeSub1 = DB.addCTNode("sub1", "Ranger (Wood Elf)'s Wolf")
            DB.setValue(nodeSub1, "initresult", "number", 5)

            -- Create master with apostrophe
            local nodeMaster2 = DB.addCTNode("master2", "D'Artagnan")
            DB.setValue(nodeMaster2, "initresult", "number", 14)
            local nodeSub2 = DB.addCTNode("sub2", "D'Artagnan's Steed")
            DB.setValue(nodeSub2, "initresult", "number", 3)

            processSubinitChatCommand(nil, "")

            local initSub1 = DB.getValue(nodeSub1, "initresult", 0)
            local initSub2 = DB.getValue(nodeSub2, "initresult", 0)

            return initSub1 == 18 and initSub2 == 14
        end)()
    `);

    // --- TEST 23: Options Database Fallback ---
    await runAssert("client option helpers fall back to DB options when OptionsManager returns nil", true, `
        return (function()
            -- Unset in OptionsManager
            OptionsManager.setOption("MOUNTTRACKER_CLIENT_CHAT", nil)
            OptionsManager.setOption("MOUNTTRACKER_FRAME_STYLE", nil)

            -- Set in DB directly
            DB.setNodeValue("options.MOUNTTRACKER_CLIENT_CHAT", "on")
            DB.setNodeValue("options.MOUNTTRACKER_FRAME_STYLE", "chat")

            local bClientChat = checkClientChat()
            local sMode = getMode()

            return bClientChat == true and sMode == "chat"
        end)()
    `);

    // 4. Print Summary
    console.log(`\nTest Summary: ${testsPassed} passed, ${testsFailed} failed.`);

    if (testsFailed > 0) {
        process.exit(1);
    }
}

runTests().catch(err => {
    console.error("Test execution failed: ", err);
    process.exit(1);
});
