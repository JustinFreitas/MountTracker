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
        local nodeActiveCT = CombatManager.getActiveCT()

        -- Only process client MountTracker notifications if it's our turn (we control the activeCT node).
        if nodeCT and nodeActiveCT and CombatManager.getCurrentUserCT() == nodeActiveCT then
            if subselection == 2 then
                notifyMount(nodeCT, false)
            elseif subselection == 3 then
                notifyMount(nodeCT, true)
            elseif subselection == 5 then
                MountTracker.notifyDismount()
            end
        else
            MountTracker.displayChatMessage("Combat must be active and it must be your turn to mount/dismount.", true)
        end

        return
    end

    if super and super.onMenuSelection then
        super.onMenuSelection(selection, subselection, subsubselection)
    end
end

function notifyMount(nodeCT, bUncontrolledMount)
    -- Pass the node path too so the host can resolve the exact clicked mount, disambiguating
    -- duplicate-named actors (e.g. two "Warhorse" entries) rather than matching by name.
    MountTracker.notifyMount(ActorManager.getDisplayName(nodeCT), bUncontrolledMount, nodeCT.getPath())
end
