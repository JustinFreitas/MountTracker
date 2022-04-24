# MountTracker

https://github.com/JustinFreitas/MountTracker

MountTracker v1.0, by Justin Freitas

ReadMe and Usage Notes

The purpose of this Fantasy Grounds 5e extension is to allow for Combat Tracker tracking of an actors mount state along with outputting some helpful text in the chat regarding the mount state and associated rules.

Features:
- When mounting, size checks are made (mount must be at least one size larger than rider).
- On any action that involves mounted combat rules (i.e. mounting, dismounting, attacking from mount, being attacked while mounted), rule reminders will be output to the DM in the chat.
- 

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
