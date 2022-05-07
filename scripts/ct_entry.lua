function onInit()
	if super and super.onInit then
		super.onInit();
	end

    local nPosition = 3
    while(not pcall(registerMenuItem, "MountTracker", "white_mount_icon", nPosition)
          and nPosition <= 8)
    do
        nPosition = nPosition + 1
    end

    registerMenuItem("Controlled Mount", "c_icon", nPosition, 2)
    registerMenuItem("Uncontrolled Mount", "u_icon", nPosition, 3)
    registerMenuItem("Dismount", "d_icon", nPosition, 5)
end

function onMenuSelection(selection, subselection)
    local nodeCT = getDatabaseNode()
    if not nodeCT then return end

    if selection == 3 then
        if subselection == 2 then
            mount(nodeCT, false)
        elseif subselection == 3 then
            mount(nodeCT, true)
        elseif subselection == 5 then
            dismount()
        end

        return
    end

    -- if selection == 6 and subselection == 7 then
    --     -- Delete any corresponding rider/mount effect.
	-- 	MountTracker.deletePairedEffectNode(nodeCT)
	-- end

    super.onMenuSelection(selection, subselection)
end

function dismount()
    MountTracker.processDismountChatCommand()
end

function mount(nodeCT, bUncontrolledMount)
    MountTracker.processMountChatCommand(ActorManager.getDisplayName(nodeCT), bUncontrolledMount)
end

function delete()
    super.delete()
    MountTracker.clearAllMountTrackerDataFromCT(true)
end