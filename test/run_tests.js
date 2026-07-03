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

        -- Mock Database structure
        dbData = {}
        function DB.setNodeValue(path, val)
            dbData[path] = val
        end
        
        function DB.getValue(node, field, default)
            local nodePath = ""
            if type(node) == "table" and node.path then
                nodePath = node.path
            elseif type(node) == "string" then
                nodePath = node
            end
            
            local fullPath = nodePath .. "." .. field
            if dbData[fullPath] ~= nil then
                return dbData[fullPath]
            end
            return default
        end

        function DB.findNode(nodePath)
            if type(nodePath) == "table" then return nodePath end
            return { path = nodePath }
        end

        local dbChildren = {}
        function DB.setChildren(nodePath, children)
            dbChildren[nodePath] = children
        end

        function DB.getChildren(node, field)
            local nodePath = ""
            if type(node) == "table" and node.path then
                nodePath = node.path
            elseif type(node) == "string" then
                nodePath = node
            end
            
            local fullPath = nodePath
            if field then
                fullPath = nodePath .. "." .. field
            end
            
            local children = dbChildren[fullPath] or {}
            local list = {}
            for k, v in pairs(children) do
                list[k] = { path = fullPath .. "." .. k }
            end
            return list
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
    `);

    // 2. Load the actual mounttracker script
    console.log("Loading scripts/mounttracker.lua into VM...");
    const luaCodePath = path.join(__dirname, '../scripts/mounttracker.lua');
    const luaCode = fs.readFileSync(luaCodePath, 'utf8');
    
    await lua.doString(luaCode);
    console.log("MountTracker loaded successfully inside VM.\n");

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
    await lua.doString("Interface.setVersion(3, 3, 10)");
    await runAssert("checkFGC() FGC", true, "return checkFGC()");
    await lua.doString("Interface.setVersion(4, 1, 0)");
    await runAssert("checkFGC() FGU", false, "return checkFGC()");

    // --- TEST 2: escapePattern ---
    await runAssert("escapePattern normal", "hello", "return escapePattern('hello')");
    await runAssert("escapePattern with brackets", "mount% %(controlled%)", "return escapePattern('mount (controlled)')");

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
