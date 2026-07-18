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

        -- Mock Interface
        local major, minor, patch = 4, 1, 0
        function Interface.getVersion() return major, minor, patch end
        function Interface.setVersion(ma, mi, pa)
            major, mi, patch = ma, mi, pa
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
        function Comm.registerSlashHandler() end
        function Comm.addChatMessage(msg)
            table.insert(chatMessages, msg.text)
        end
        function Comm.deliverChatMessage(msg)
            table.insert(chatMessages, msg.text)
        end
        function Comm.getChatMessages()
            return chatMessages
        end
        function Comm.clearChatMessages()
            chatMessages = {}
        end

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

        function DB.getValue(node, field, default)
            local fullPath = nodePathOf(node) .. "." .. field
            if dbData[fullPath] ~= nil then
                return dbData[fullPath]
            end
            return default
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
            return actorMap[nodeCT.path]
        end
        function ActorManager.setActor(nodeCTPath, actor)
            actorMap[nodeCTPath] = actor
        end
        function ActorManager.getDisplayName(node)
            return DB.getValue(node, "name", "Unknown")
        end
        function ActorManager.getFaction(v) return "friend" end
        function ActorManager.getRecordType(v) return "pc" end

        -- Mock ActionsManager
        function ActionsManager.registerResultHandler() end
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
