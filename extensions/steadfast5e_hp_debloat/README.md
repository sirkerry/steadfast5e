# Steadfast5e - HP Debloat

Part of the [Steadfast5e](https://forge.fantasygrounds.com/) suite for grittier, OSR-style 5E play.

## What it does

Compresses hit point totals for player characters and NPCs, making combat more lethal and resource management more meaningful at all levels.

### Formula

**Level 1:** Hit die maximum + CON modifier (same as standard 5E)

**Each level beyond 1st:** Hit die maximum / 2, no additional CON modifier

| Class | Hit Die | Level 1 HP (CON +0) | Per Level Beyond 1st |
|-------|---------|---------------------|----------------------|
| Barbarian | d12 | 12 | +6 |
| Fighter, Paladin, Ranger | d10 | 10 | +5 |
| Cleric, Druid, Monk, Rogue, Warlock, Bard | d8 | 8 | +4 |
| Sorcerer, Wizard | d6 | 6 | +3 |

### Multiclass characters

The extension tries each class as the level 1 candidate and picks whichever assignment produces the highest total HP. In practice this always means the class with the largest hit die gets the level 1 slot.

### Feats and racial features

Tough (+2 HP/level), Dwarven Toughness (+1 HP/level), and Draconic Resilience are applied on top of the formula as normal. No special handling is needed — they stack automatically.

### Existing characters

When the extension loads, it recalculates max HP for all affected characters and adjusts current HP proportionally (ratio of current/max is preserved, rounded down). This runs every session load; the calculation is idempotent.

## Options

All options appear in the **House Rules** section of the Options panel and are GM-only.

| Option | Default | Description |
|--------|---------|-------------|
| HP Debloat: Apply to PCs | On | Apply formula to player-owned characters |
| HP Debloat: Apply to NPCs | On | Apply formula to GM-controlled charsheet characters (companions, hirelings, sidekicks) |
| HP Debloat: Apply to Monsters | Off | Apply formula to monster statblock HP using their listed hit dice |
| HP Debloat: Level Up Mode | Auto Apply | Auto Apply: HP is added silently on level up. Prompt Player: the calculated gain is posted to chat for manual application instead. |

## Compatibility

- D&D 5E 2014 (Legacy) and 2024
- Compatible with other Steadfast5e extensions
- Hooks into the existing 5E level-up flow; does not replace it wholesale

## Installation

Drop the `steadfast5e_hp_debloat` folder into your Fantasy Grounds Unity `extensions/` directory and enable it when loading a 5E campaign.
