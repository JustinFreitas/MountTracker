# MountTracker

https://github.com/JustinFreitas/MountTracker

MountTracker v1.4, by Justin Freitas

ReadMe and Usage Notes

The purpose of this Fantasy Grounds 5e extension is to allow for Combat Tracker tracking (via effects only) of an actors mount state along with outputting some helpful SRD rule text (thanks OGL!) in the chat regarding the mount state and associated rules. This includes a distinction between controlled and uncontrolled (aka independent) mounts for the purpose of clarity and also displaying the appropriate rule hints.  The GM can make mount associations via drag/drop of CT actors (drag the rider name to the mount, not the portrait) to a target mount, right click CT radial menu on a target mount (or for dismount), or chat commands to invoke the action.  Players can mount/dismount via the CT's right click radial menu.

GM MountTracker Chat Commands:

-Current actor MountTracker status:
/mt
or
/mounttracker

- Clear all MountTracker effects from Combat Tracker (manually deleting effects is always an option too):
/mt clear
or
/mounttracker clear

- Have the current actor mount another actor as the rider:
/mount [TARGET_MOUNT]
Ex. /mount Warhorse

- Have the current actor (who is riding a mount) dismount its mount:
/dismount


Combat Tracker Radial Menu:

For the current Combat Tracker actor, the GM or the Player can right click a target actor to mount as a rider (or dismount if they are already riding).  In the radial menu, the Player can select between Controlled, Uncontrolled (Independent), and Dismount.


Features:
- When mounting, validation is performed where things like size checks are made (mount must be at least one size larger than rider), debilitating conditions are considered, and zero speed.
- Distinguishes between controlled and uncontrolled/independent mounts, selected at time of mount. Note: For GM CT actor drag/drop, holding control when dropping will be uncontrolled/independent.
- On any action that involves mounted combat rules (i.e. mounting, dismounting, attacking from mount, being attacked while mounted, controlled or uncontrolled/independent), rule reminders will be output to the DM in the chat (verbosity set in options).
- It knows to consider debilitating conditions or speed of zero (i.e. grappled) when mounting/dismounting.
- On the rider's turn, chat output is shown (optionally) that displays the mounted speed and some rule help for both controlled and uncontrolled/independent scenarios.
- Works with unidentified actors in the Combat Tracker.
- Has a chat command interface for /mount [TARGET_ACTOR] (controlled mount), /ucmount [TARGET_ACTOR] (uncontrolled/independent mount), /dismount (no target, affects current CT actor), /mt clear.
- Has a radial menu interface for mount/dismount that is player accessible and works for the current actor in the Combat Tracker (that's where the chosen menu action will be applied).
- If attacking from a mount, display a chat message with any rules restrictions/guidance.
- Options for chat verbosity, size enforcement, skipping controlled mount's turn via SKIPTURN.

Future Enhancements:
- Add a little button to the CT actor so players/DM can click it to mount/dismount.
- Only Carried or Equiped Mounts (shouldn't it also be required to be in the CT?) will be considered.
- The standard mount types will be accounted for as well as anything that has a (mount) entry somewhere in the line.  For example:  MyUniqueCreature (mount)
- Any, the GM (and probably player also) can issue a mount/dismount console command (i.e. /mount or /dismount) to trigger the functionality.  It will set an effect and output chat info that will be different for active vs inactive combat.
- Set the initiative of the mount NPC actor in the Combat Tracker at time of command if the name of the NPC is supplied as a command argument (i.e. /mount Warhorse) and doing that would set the init of warhorse to rider init - .1.  If this is an optional rule, have an option for it in settings.
- If attacking a mounted actor (has Mount effect), choose to attack mount or rider chat message (or even issue the roll against the new CT target as a passthrough).
- On turn start, recognize if the turn is on the mount CT actor.  If so, show the mount status and any other pertinent information.
- On init change or any turn start, scrub entire CT for Rider/Mount init fixups.
- If not in combat, don't show the combat information when mounting/dismounting.
- On each turn, walk the combat list and move any controlled mount in the initiative to it's rider's init.  Only change the value if it would actually change.
- Is the actor someone's mount? Must be NPC or PC.  Has the Rider (PHB term) effect.  Rider can be blank/(unspecified).  Name (toLower) must match a mount effect on exactly one CT actor (or first, but multiple is error condition and should be reported to GM).  Must be Friendly.
- If actor is on a mount, if the mount is uncontrolled/independent, remind the chat that they cannot move independently unless dismounting first.  If it's controlled it can take one of the four actions.
- If target mount/npc is intelligent (what int value? 6? 8?), it's always uncontrolled/independent.
- For FGC, incorporate SKIPTURN logic right into MountTracker so that it works the same as FGU in that regard.  Right now, I rely on a SKIPTURN extension for FGC.
- Need an effect add handler so that if Prone is added to a rider or mount then the special rules will display in the chat for notification/review.
		-- Something like:  for _,nodeEffect in pairs(DB.getChildren(nodeActor, EFFECTS)) do
		--  This is for features on abilities tab but we need it for the effects nodes.
		--local featureNamePath = "charsheet.*.featurelist.*.name"
		--DB.addHandler(featureNamePath, "onAdd", onFeatureNameAddOrUpdate)
		--DB.addHandler(featureNamePath, "onUpdate", onFeatureNameAddOrUpdate)


Changelist:
- v1.0 - Initial version.
- v1.1 - Changed the in-combat firing of the mount functionality fromn onTurnStart to requestActivation.  Now, it works when you click the left CT bar to activate an actor that way (and still works when using the Next Actor button too).  Migrated over the build tool for consistency in building the extension output.
- v1.2 - Updated the icon using Sir Motte's template.  Don't use crossed eye icon in chat messages.
- v1.3 - Another icon update, this time 42px to conform to new theme style.
- v1.3.1 - Don't display MountTracker information to the players if the rider is an NPC and not a friend.  This will be enforced even if Show to Players is enabled in the options.
- v1.4 - Add an option for Frame Style (defaulting to None) to frame the MountTracker chat output.  The options are None, Chat, Story, Whisper and they utilize the CoreRPG output modes for these selections.
