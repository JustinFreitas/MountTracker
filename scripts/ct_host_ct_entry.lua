local nMenuSlot = nil

function onInit()
	if super and super.onInit then
		super.onInit();
	end

    nMenuSlot = nil
    if hasMenuItem then
        for _, nCandidate in ipairs({ 3, 5, 7, 8, 4, 2, 1 }) do
            if not hasMenuItem(nCandidate) then
                nMenuSlot = nCandidate
                break
            end
        end
    else
        nMenuSlot = 3
    end

    if nMenuSlot then
        registerMenuItem("MountTracker", "white_mount_icon", nMenuSlot)
        registerMenuItem("Controlled Mount", "c_icon", nMenuSlot, 2)
        registerMenuItem("Uncontrolled Mount", "u_icon", nMenuSlot, 3)
        registerMenuItem("Dismount", "d_icon", nMenuSlot, 5)
    end
end

function onMenuSelection(selection, subselection, subsubselection)
    if nMenuSlot and selection == nMenuSlot then
        local nodeCT = getDatabaseNode()
        if nodeCT then
            if subselection == 2 then
                mount(nodeCT, false)
            elseif subselection == 3 then
                mount(nodeCT, true)
            elseif subselection == 5 then
                dismount(nodeCT)
            end
        end

        return
    end

    if super and super.onMenuSelection then
        super.onMenuSelection(selection, subselection, subsubselection)
    end
end

function dismount(nodeCT)
    -- Pass the clicked node explicitly, same as mount() below, so a duplicate-named CT entry
    -- elsewhere can't cause the wrong actor to be dismounted.
    MountTracker.processDismountChatCommand(nil, ActorManager.getDisplayName(nodeCT), nodeCT)
end

function mount(nodeCT, bUncontrolledMount)
    -- Pass the clicked node explicitly so duplicate-named mounts (e.g. two "Warhorse"
    -- actors) resolve to the exact one the user selected, not the first name match.
    MountTracker.processMountChatCommand(ActorManager.getDisplayName(nodeCT), bUncontrolledMount, nil, nodeCT)
end

function delete()
    if super and super.delete then
        super.delete()
    end

    if MountTracker then
        MountTracker.clearAllMountTrackerDataFromCT(true)
    end
end