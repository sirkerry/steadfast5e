# Steadfast5e — Expanded Skills

Part of the **Steadfast5e** suite of Fantasy Grounds Unity extensions for grittier, more grounded 5E play.

Replaces the standard 18 5E skills with **26 flat skills** that give every ability score a broader role, tighten scope boundaries between similar skills, and eliminate the passive-feel redundancy of the original list.

---

## The 26 Skills

| Skill | Ability | Notes |
|---|---|---|
| Athletics | STR | Unchanged |
| Acrobatics | DEX | Unchanged |
| Stealth | DEX | Unchanged |
| Trickery | DEX | Renamed from Sleight of Hand |
| Academics | INT | Renamed from History |
| Arcana | INT | Unchanged |
| Crafting | INT | New |
| Investigation | INT | Unchanged |
| Nature | INT | Restored as pure knowledge skill |
| Religion | INT | Unchanged |
| Science | INT | New |
| Beastcraft | WIS | Renamed from Animal Handling |
| Cooking | WIS | New |
| Healing | WIS | Renamed from Medicine |
| Herblore | WIS | New |
| Insight | WIS | Unchanged |
| Occult | WIS | New |
| Survival | WIS | Unchanged (scope tightened vs Tracking) |
| Tracking | WIS | New |
| Wildcraft | WIS | Replaces active elements of old Nature |
| Endurance | CON | New |
| Perception | CON | Moved from WIS — passive perception uses CON |
| Deception | CHA | Absorbs Intimidation |
| Perform | CHA | Renamed from Performance |
| Persuasion | CHA | Unchanged |
| Streetwise | CHA | New |

---

## Migration

When the extension loads on an existing 5E campaign, it automatically:

- Renames skill nodes on character sheets (old name → new name, proficiency carried over)
- Absorbs Intimidation proficiency into Deception (takes the higher value)
- Updates Perception's ability score from WIS to CON
- Creates fresh nodes for the 8 new skills
- Remaps old skill names in the Character Wizard dropdown
- Ensures `SKILL:` effects using old names still apply to their renamed equivalents

---

## Companion Module

Install **Steadfast5e Expanded Skills** (`steadfast5e_expanded_skills.mod`) alongside this extension. It provides GM and player reference entries for all 26 skills in the FGU library, including scope descriptions, boundaries, example uses, and GM guidance.

Activate the module once per campaign from **Library → Modules**. FGU remembers the choice on all subsequent loads.

---

## Compatibility

- Fantasy Grounds Unity 4.x
- D&D 5E 2014 (Legacy) and 2024 rulesets
- Part of the Steadfast5e suite — compatible with other Steadfast5e extensions
