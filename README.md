# azeroth-addons

Small quality-of-life addons for the WoW-based survivors-likes:

- **Azeroth Survivors** (the original 1.12 "benilla" client) - [`survivors/`](survivors)
- **Azeroth Survivors Reborn** (the 3.3.5a / WotLK client) - [`reborn/`](reborn)
- **Hordes of Azeroth** (1.12 "benilla" client) - [`hordes/`](hordes)

Every addon is plain Lua with no libraries. Each folder under `survivors/`, `reborn/` and `hordes/` is
one addon: copy it into the game's addon folder (see each section) and tick it on the character
screen's AddOns list.

The Survivors and Reborn folders hold the same five addons in two versions: the Reborn ones are ported
to the 3.3.5a calling convention (`self`, handler arguments) and marked `## Interface: 30300`. Use the
folder that matches your client.

## Azeroth Survivors and Reborn

These read the game's addon API (`AZS_GetWorldAnchors`, `AZS_GetPlayerPosition`, `AZS_CHESTS`,
`AZS_LAIRS`, `AZS_GetDebuffs`, `AZS_RUN`...). Reborn ships the same API under the same names in its
`AzerothSurvivorsAPI` addon.

Install to:

- Survivors: `<game>\benilla-config\AddOns\`
- Reborn: `<game>\Interface\AddOns\`

| Addon | What it does | Command |
|---|---|---|
| **AZSRaidMarkers** | Raid icons over the bosses: skull on the final boss, cross on bosses, diamond on guardians, optional triangle on elites, each with a name and health plate. | `/azrm on \| off \| elites \| plates` |
| **AZSCacheArrow** | An arrow to the nearest cache. Turns green and pulses with "CAN OPEN" when you have the gold, and shows the gold against the price. Pulsing coin icons over caches you can afford. | `/azca on \| off \| coins \| reset` |
| **AZSLairs** | A lair window: each guardian's state, health and max health, and an `xN` power ratio against the first guardian of that lair this run. Labels over the lairs and a red arrow to the flagged lair. | `/azlair on \| off \| markers \| arrow \| reset` |
| **AZSDebuffWatch** | Your watched debuffs on the boss or awake guardian you are fighting. Missing ones pulse red, ones about to expire flash, and a warning plays when one falls off. With no watch list, every debuff shows. | `/azdw add <name> \| remove <name> \| list \| clear \| sound \| on \| off \| reset` |
| **AZSGoldSound** | Plays a sound of your choice when your gold goes up. **Bring your own sound**: put a `gold.wav` in the addon folder (16-bit PCM WAV, about a second long). | `/azgold on \| off \| test` |

Every frame can be dragged; `reset` puts it back.

### Reborn only

| Addon | What it does | Command |
|---|---|---|
| **AZSRebornTweaks** | Built for running [BlackwellUI](https://github.com/Blackwellcode/BlackwellUI) on Reborn. Hides AzerothSurvivorsUI's player, target and target-of-target frames, its boss bar, its gold/cache display and its action bars, and draws them again in BlackwellUI's style: the boss bar ("X approaches N%" or the boss's health) at the top, the gold, cache price and event currency as tiles above BlackwellUI's damage meter, and the hero's spells (icon, rank, cooldown) as tiles above BlackwellUI's chat. Works without BlackwellUI too, with a plain dark look. | `/azbar on \| off \| stock \| res \| spells \| reset` |

`/azbar stock` brings AzerothSurvivorsUI's own frames back (after a restart).

Notes for Reborn:

- `/reload` can hard-crash the Reborn client (a native crash, not an addon error). Restart the game
  instead to load addon changes.
- Reborn's run data is not sent as addon messages, so AZSGoldSound polls `AZS_RUN.gold` there.

## Hordes of Azeroth

Hordes has no public addon API; these read the `BONK~` system lines its server sends to its own
HUD addon (`HordesOfAzeroth`), through that addon's `VanillaBonkUI.Listen`. They need `HordesOfAzeroth`
enabled.

Install to `<game>\benilla-config\AddOns\`.

| Addon | What it does | Command |
|---|---|---|
| **HoAArrows** (folder `HoAChestArrow`) | A row of arrows to the nearest chest, shrine, event, miniboss, boss and vendor, with name and yards. Chests are gold, or green and pulsing when they open for free. Uses Hordes' own arrow art and turns with the camera. | `/hoaarrow on \| off \| reset \| chest \| shrine \| event \| miniboss \| boss \| vendor` |
| **HoABlackwellSkin** | Reskins Hordes' bottom hero bar and damage meter in [BlackwellUI](https://github.com/Blackwellcode/BlackwellUI)'s style: flat panels instead of the stone bar and gryphons, rarity borders instead of the glow, BlackwellUI's bar texture and font, and the level badge lifted clear of the XP rail. Also hides the chat and sets the UI scale (0.8 by default). | `/hoaskin on \| off \| chat \| scale <0.5-1.5> \| sweep \| dump` |

The arrows only know objectives the server reports after they load; ones already up appear on the
server's next update.

### Engine quirks (Hordes)

Hordes runs on its own engine, which draws some things differently from the stock 1.12 client. The
skin works around them:

- Textures are drawn in the order they were made, whatever their draw layer, so backdrops go on their
  own frame behind instead of on the frame itself.
- Additive textures ignore alpha. The skin switches them to normal blending before hiding them.
- The `HIGHLIGHT` layer is drawn all the time, not only on mouse-over, and can't be hidden afterwards.
  The hero bar's slot highlight greys every icon. The skin can't remove it; to fix it, delete these four
  lines in `HordesOfAzeroth\VanillaBonkHeroBar.lua` (`CreateSlot`). A Hordes update puts them back.

  ```lua
  slot.highlight = slot:CreateTexture(nil, "HIGHLIGHT")
  slot.highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
  slot.highlight:SetBlendMode("ADD")
  slot.highlight:SetAllPoints(slot)
  ```

- The cooldown sweep model draws as a grey wash, so the skin hides it (`/hoaskin sweep` keeps it).

`/hoaskin dump` writes every visible texture on the hero bar to the saved variables, which helps
track down what a new layer is.

## Not included

- **BlackwellUI** is by Pierre (Blackwellcode), All Rights Reserved; get it from its own repository.
  The addons above only use it when it is there.
- No sound files: AZSGoldSound plays whatever `gold.wav` you put in its folder.

## License

MIT - see [LICENSE](LICENSE).
