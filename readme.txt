MountTracker for D&D 5E (Fantasy Grounds Unity & Classic)

https://github.com/JustinFreitas/MountTracker

MountTracker is a Fantasy Grounds extension for the D&D 5E ruleset that automates the tracking of mounted combatants, controlled and independent mounts, turn flow, initiative synchronization, and mounted combat rules reminders in the Combat Tracker (CT).

================================================================================
KEY FEATURES
================================================================================

1. Combat Tracker Effect Automation:
   - Establishes linked Combat Tracker effects: "Mount: [Name]; MountTracker" on the rider, and "Rider: [Name]; MountTracker" on the mount.
   - Tracks both Controlled and Uncontrolled (Independent) mounts with appropriate rules enforcement.

2. Controlled Mount Initiative & Turn Management:
   - When pairing a controlled mount, the mount's initiative is automatically updated to match the rider's initiative.
   - Optionally applies the "; SKIPTURN" effect to the mount, allowing seamless play where the rider controls the mount on their turn.

3. Drag-and-Drop & Radial Menu CT Pairing:
   - Drag-and-Drop: The GM can drag a rider's Combat Tracker entry (or token) and drop it directly onto the mount's CT entry to pair them immediately. Holding Ctrl while dropping pairs them as an uncontrolled mount.
   - Radial Menu: Both GM and players can right-click any Combat Tracker actor to access radial menu options for mounting (Controlled or Uncontrolled) or dismounting.

4. 5E Mounted Combat Rules Reminders:
   - Turn Reminders: Displays mount speed and valid actions on the rider's or mount's turn.
   - Action Restrictions: Reminds the GM that controlled mounts can only Dash, Disengage, and Dodge.
   - Mounted Attacks: When a mounted creature attacks or is attacked, chat reminders display pertinent 5E mounted combat rules (e.g. opportunity attack target selection, forced movement, and DC 10 Dex saves against falling prone).

5. Size Validation & Condition Checks:
   - Enforces 5E size requirements (mount must be at least one size category larger than rider), configurable via options.
   - Checks for debilitating conditions (unconscious, stunned, paralyzed, incapacitated, petrified, grappled, prone) before permitting mounting or dismounting.

6. Unidentified Creature Privacy:
   - When mounting or riding an unidentified NPC, effects are automatically flagged as GM-only (nGMOnly = 1), and player-facing chat outputs mask the creature's true name using its unidentified display name.

7. Dice Tower & Secret Roll Support:
   - Attack rolls made secretly or dropped into the Dice Tower deliver rule reminders privately to the GM without leaking to players.

8. Sub-Initiative Synchronization (/subinit):
   - Utility command for GMs to quickly synchronize the initiative of all minions, mounts, and summons named with a possessive prefix (e.g. "Bob's Warhorse" matching rider "Bob").

================================================================================
CHAT COMMANDS
================================================================================

/mount [MountName]
Pairs the current Combat Tracker actor as a rider with the specified mount (Controlled).

/ucmount [MountName]
Pairs the current Combat Tracker actor as a rider with the specified mount (Uncontrolled/Independent).

/dismount [OptionalName]
Dismounts the active actor or the specified actor/mount pair.

/mt or /mounttracker
Displays the current combatant's mount status.

/mt clear or /mounttracker clear
Removes all Mount and Rider effects across the Combat Tracker.

/subinit
Walks the Combat Tracker and matches initiative for all child combatants named Actor's <Creature> (Host only).

================================================================================
COMBAT TRACKER RADIAL MENU
================================================================================

Right-click any Combat Tracker actor entry to access the Mount radial sub-menu:
- Controlled Mount: Establishes controlled mount pairing and synchronizes initiative.
- Uncontrolled Mount: Establishes independent mount pairing.
- Dismount: Clears the pairing from both mount and rider.

================================================================================
CONFIGURATION SETTINGS (GM OPTIONS)
================================================================================

Located under the Options window in the "MountTracker (GM)" section:

- Chat: Show to Player [On / Off] (Default: On)
  When enabled, rule reminders and mounted status updates are shared to player chat; when disabled, messages are host-only.

- CT: Skip Controlled Mount Turn [On / Off] (Default: On)
  Automatically appends "; SKIPTURN" to controlled mounts so their turn is skipped in combat.

- CT: Enforce Size [On / Off] (Default: On)
  Requires mounts to be at least one size larger than riders when mounting.

- Chat: Verbose Rule Reminders [Off / Standard / Max] (Default: Max)
  Controls the verbosity of mounted combat rule guidance output to chat.

- Chat: Frame style [Chat / Story / Whisper / None] (Default: None)
  Selects the visual chat frame style for MountTracker notifications.

================================================================================
COMPATIBILITY & REQUIREMENTS
================================================================================

- Fantasy Grounds Unity (FGU) & Fantasy Grounds Classic (FGC)
- Ruleset: D&D 5E (2014 & 2024 compatible)
- Fully interoperable with StealthTracker, LanguageTracker, and EncumbranceTracker.
