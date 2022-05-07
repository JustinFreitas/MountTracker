function onInit()
	if super and super.onInit then
		super.onInit();
	end

    registerMenuItem("MountTracker", "mount_icon", 3)
    registerMenuItem("Mount", "mount_icon", 3, 2)
    registerMenuItem("Mount (uncontrolled)", "mount_icon", 3, 3)
    registerMenuItem("Dismount", "mount_icon", 3, 5)
end

function onMenuSelection(selection, subselection)
	if selection == 3 then
        local nodeCT = getDatabaseNode()
        if not nodeCT then return end

        if subselection == 2 then
            mount(nodeCT, false)
        elseif subselection == 3 then
            mount(nodeCT, true)
        elseif subselection == 5 then
            dismount()
        end
    end
end

function dismount()
    MountTracker.processDismountChatCommand()
end

function mount(nodeCT, bUncontrolledMount)
    MountTracker.processMountChatCommand(ActorManager.getDisplayName(nodeCT), bUncontrolledMount)
end
