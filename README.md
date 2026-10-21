# MountTracker for D&D 5E (Fantasy Grounds Unity & Classic)

[![GitHub](https://img.shields.io/badge/GitHub-JustinFreitas%2FMountTracker-blue.svg)](https://github.com/JustinFreitas/MountTracker)

**MountTracker** is a Fantasy Grounds extension for the **D&D 5E** ruleset that automates the tracking of mounted combatants, controlled and independent mounts, turn flow, initiative synchronization, and mounted combat rules reminders in the Combat Tracker (CT).

---

## Key Features

1. **Combat Tracker Effect Automation**:
   * Establishes linked Combat Tracker effects: `Mount: [Name]; MountTracker` on the rider, and `Rider: [Name]; MountTracker` on the mount.
   * Tracks both **Controlled** and **Uncontrolled (Independent)** mounts with appropriate rules enforcement.

2. **Controlled Mount Initiative & Turn Management**:
   * When pairing a controlled mount, the mount's initiative is automatically updated to match the rider's initiative.
   * Optionally applies the `; SKIPTURN` effect to the mount, allowing seamless play where the rider controls the mount on their turn.

3. **Drag-and-Drop & Radial Menu CT Pairing**:
   * **Drag-and-Drop**: The GM can drag a rider's Combat Tracker entry (or token) and drop it directly onto the mount's CT entry to pair them immediately. Holding `Ctrl` while dropping pairs them as an uncontrolled mount.
   * **Radial Menu**: Both GM and players can right-click any Combat Tracker actor to access radial menu options for mounting (Controlled or Uncontrolled) or dismounting.

4. **5E Mounted Combat Rules Reminders**:
   * **Turn Reminders**: Displays mount speed and valid actions on the rider's or mount's turn.
   * **Action Restrictions**: Reminds the GM that controlled mounts can only Dash, Disengage, and Dodge.
   * **Mounted Attacks**: When a mounted creature attacks or is attacked, chat reminders display pertinent 5E mounted combat rules (e.g. opportunity attack target selection, forced movement, and DC 10 Dex saves against falling prone).

5. **Size Validation & Condition Checks**:
   * Enforces 5E size requirements (mount must be at least one size category larger than rider), configurable via options.
   * Checks for debilitating conditions (unconscious, stunned, paralyzed, incapacitated, petrified, grappled, prone) before permitting mounting or dismounting.

6. **Unidentified Creature Privacy**:
   * When mounting or riding an unidentified NPC, effects are automatically flagged as GM-only (`nGMOnly = 1`), and player-facing chat outputs mask the creature's true name using its unidentified display name.

7. **Dice Tower & Secret Roll Support**:
   * Attack rolls made secretly or dropped into the Dice Tower deliver rule reminders privately to the GM without leaking to players.

8. **Sub-Initiative Synchronization (`/subinit`)**:
   * Utility command for GMs to quickly synchronize the initiative of all minions, mounts, and summons named with a possessive prefix (e.g. `"Bob's Warhorse"` matching rider `"Bob"`).

---

## Chat Commands

| Command | Description |
| :--- | :--- |
| `/mount [MountName]` | Pairs the current Combat Tracker actor as a rider with the specified mount (Controlled). |
| `/ucmount [MountName]` | Pairs the current Combat Tracker actor as a rider with the specified mount (Uncontrolled/Independent). |
| `/dismount [OptionalName]` | Dismounts the active actor or the specified actor/mount pair. |
| `/mt` or `/mounttracker` | Displays the current combatant's mount status. |
| `/mt clear` or `/mounttracker clear` | Removes all Mount and Rider effects across the Combat Tracker. |
| `/subinit` | Walks the Combat Tracker and matches initiative for all child combatants named `Actor's <Creature>` (Host only). |

---

## Combat Tracker Radial Menu

* **Rider / Active Actor**: Right-click the Combat Tracker entry to access the **Mount** sub-menu:
  * **Controlled Mount**: Establishes controlled mount pairing and synchronizes initiative.
  * **Uncontrolled Mount**: Establishes independent mount pairing.
  * **Dismount**: Clears the pairing from both mount and rider.

---

## Configuration Settings (GM Options)

Located under the **Options** window in the **MountTracker (GM)** section:

| Option | Values | Default | Description |
| :--- | :--- | :--- | :--- |
| **Chat: Show to Player** | `On` / `Off` | `On` | When enabled, rule reminders and mounted status updates are shared to player chat; when disabled, messages are host-only. |
| **CT: Skip Controlled Mount Turn** | `On` / `Off` | `On` | Automatically appends `; SKIPTURN` to controlled mounts so their turn is skipped in combat. |
| **CT: Enforce Size** | `On` / `Off` | `On` | Requires mounts to be at least one size larger than riders when mounting. |
| **Chat: Verbose Rule Reminders** | `Off` / `Standard` / `Max` | `Max` | Controls the verbosity of mounted combat rule guidance output to chat. |
| **Chat: Frame style** | `Chat` / `Story` / `Whisper` / `None` | `None` | Selects the visual chat frame style for MountTracker notifications. |

---

## Compatibility

* **Fantasy Grounds Unity (FGU)** & **Fantasy Grounds Classic (FGC)**
* **Ruleset**: D&D 5E (2014 & 2024 compatible)
* Fully interoperable with **StealthTracker**, **LanguageTracker**, and **EncumbranceTracker**.

---

## Version History

* **v1.11** (October 2026):
  * CoreRPG modernization: Wrapped `CombatDropManager.handleAnyDrop` for reliable CT drag-and-drop pairings in modern FGU.
  * Removed debug console logging from attack rolls.
  * Attack reminder secrecy: Dice Tower and secret rolls deliver privately to GM.
  * Unidentified NPC protection: Sets `nGMOnly = 1` for unidentified pairs and masks true names in player chat.
  * Integrated `/subinit` slash command with regex special character escaping.
  * Added client options database fallback.
  * Standardized build package script and Forge documentation.
* **v1.10.2** (September 2026): Restored dual FGC/FGU compatibility, fixed ActorManager resolution, and added `/reload` idempotency guards.
* **v1.10.1** (July 2026): Duplicate attacker redirection in `displayProcessAttackFromMount`.
* **v1.10.0** (July 2026): Parenthesized effect parsing for GM-only effects.
* **v1.9.5** (July 2026): Disambiguated partner resolution using relationship verification.
* **v1.4** (November 2023): Initial Forge release and chat frame options.
