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
            dismount(nodeCT)
        end

        return
    end

    -- if selection == 6 and subselection == 7 then
    --     -- Delete any corresponding rider/mount effect.
	-- 	MountTracker.deletePairedEffectNode(nodeCT)
	-- end

    if super and super.onMenuSelection then
        super.onMenuSelection(selection, subselection)
    end
end

function dismount(nodeCT)
    MountTracker.processDismountChatCommand(nil, ActorManager.getDisplayName(nodeCT))
end

function mount(nodeCT, bUncontrolledMount)
    MountTracker.processMountChatCommand(ActorManager.getDisplayName(nodeCT), bUncontrolledMount)
end

function delete()
    if super and super.delete then
        super.delete()
    end

    MountTracker.clearAllMountTrackerDataFromCT(true)
end