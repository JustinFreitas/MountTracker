# MountTracker

https://github.com/JustinFreitas/MountTracker

MountTracker v1.0, by Justin Freitas

ReadMe and Usage Notes

The purpose of this Fantasy Grounds 5e extension is to allow for Combat Tracker tracking of an actors mount state along with outputting some helpful text in the chat regarding the mount state and associated rules.

Features:
- When mounting, size checks are made (mount must be at least one size larger than rider).
- On any action that involves mounted combat rules (i.e. mounting, dismounting, attacking from mount, being attacked while mounted), rule reminders will be output to the DM in the chat.
- It knows to consider debilitating conditions or speed of zero (i.e. grappled) when mounting/dismounting.

	-- TODO: On each turn, walk the combat list and move any controlled mount in the initiative to it's rider's init.  Only change the value if it would actually change.
	-- TODO: Is the actor someone's mount? Must be NPC or PC.  Has the Rider (PHB term) effect.  Rider can be blank/(unspecified).  Name (toLower) must match a mount effect on exactly one CT actor (or first, but multiple is error condition and should be reported to GM).  Must be Friendly.
	-- TODO: If actor is on a mount, if the mount is uncontrolled, remind the chat that they cannot move independently unless dismounting first.  If it's controlled it can take one of the four actions.
	-- TODO: If the actor is on a mount and it's controlled, remind the chat as such and that movement is DONE
	-- TODO: If the actor is already mounted, he cannot mount again.  DONE
	-- TODO: If the mount has a rider, it cannot get a 2nd.  DONE
	-- TODO: If the actor is on a mount, show their mounted speed (speed of the mount).  DONE
	-- TODO: Works with unidentified?  Yes, works with whatever is in the name field on CT, which is the Non-ID Name field if the actor is unidentified.  DONE
		-- TODO: Need an effect add handler so that if Prone is added to a rider or mount then the special rules will display in the chat for notification/review.
		-- Something like:  for _,nodeEffect in pairs(DB.getChildren(nodeActor, EFFECTS)) do
		-- TODO: This is for features on abilities tab but we need it for the effects nodes.
		--local featureNamePath = "charsheet.*.featurelist.*.name"
		--DB.addHandler(featureNamePath, "onAdd", onFeatureNameAddOrUpdate)
		--DB.addHandler(featureNamePath, "onUpdate", onFeatureNameAddOrUpdate)

Future Enhancements:
- Only Carried or Equiped Mounts (shouldn't it also be required to be in the CT?) will be considered.
- The standard mount types will be accounted for as well as anything that has a (mount) entry somewhere in the line.  For example:  MyUniqueCreature (mount)
- Any, the GM (and probably player also) can issue a mount/dismount console command (i.e. /mount or /dismount) to trigger the functionality.  It will set an effect and output chat info that will be different for active vs inactive combat.
- Set the initiative of the mount NPC actor in the Combat Tracker at time of command if the name of the NPC is supplied as a command argument (i.e. /mount Warhorse) and doing that would set the init of warhorse to rider init - .1.  If this is an optional rule, have an option for it in settings.
- If attacking a mounted actor (has Mount effect), choose to attack mount or rider chat message (or even issue the roll against the new CT target as a passthrough).
- If attacking from a mount, display a chat message with any rules restrictions/guidance.
- On turn start, recognize if the turn is on the mount CT actor.  If so, show the mount status and any other pertinent information.
- On init change or any turn start, scrub entire CT for Rider/Mount init fixups.
- If not in combat, don't show the combat information when mounting/dismounting.

Changelist:
- v1.0 - Initial version.
