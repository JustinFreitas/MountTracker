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
    -- Only process client MountTracker notifications if it's our turn (we control the activeCT node) or it's a friend's turn.
    if ActorManager.getFaction(vSource) == "friend"
        or CombatManager.getCurrentUserCT() == CombatManager.getActiveCT() then

        local nodeCT = getDatabaseNode()
        if not nodeCT then return end

        if selection == 3 then
            if subselection == 2 then
                notifyMount(nodeCT, false)
            elseif subselection == 3 then
                notifyMount(nodeCT, true)
            elseif subselection == 5 then
                MountTracker.notifyDismount()
            end

            return
        end
    else
        MountTracker.displayChatMessage("Combat must be active and it must be your turn to mount/dismount.", true)
    end

    if super and super.onMenuSelection then
        super.onMenuSelection(selection, subselection)
    end
end

function notifyMount(nodeCT, bUncontrolledMount)
    MountTracker.notifyMount(ActorManager.getDisplayName(nodeCT), bUncontrolledMount)
end
