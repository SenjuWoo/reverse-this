# Anti-cheat: Risk Tiers, Not a Blanket Ban

Anti-cheat is not one rule. Some multiplayer games tolerate cosmetic client-side mods; some ban any client modification; some act only on competitive advantage, economy changes or DLC unlocks. The policy changes by game and by patch, so the only safe statement is: read the current official policy, name the method, and record the account risk.

This page is a decision record, not an evasion guide. It does not describe how to defeat a detector. It describes how to decide whether a mod belongs online at all.

## Dated evidence

- **Marvel Rivals, 2026-10-15** — the official post says the team wants to preserve customization "as long as the fairness of the game is not compromised", but mods that use **memory injection and modification** "instantly trigger" anti-cheat. Prohibited examples: structural model/texture changes that create asymmetric line-of-sight, recoil/VFX removal, audio changes, and enemy model enlargement. It names `pystubber.asi` and `MarvelRivalsUnmountBlocker.asi` as files that trigger detection. Suspensions were lifted, but the post says that is not permission. <https://www.marvelrivals.com/20261015/41525_1316797.html>
- **Monster Hunter Wilds, official warning (Ver. 1.040)** — Capcom reports unauthorized modification of investigation/Field Survey data, filters or blocks modified quests, and may suspend accounts for fraudulent activity. The warning targets modified quest data, not cosmetic skins, but it is not a blanket permission for client modification. <https://www.monsterhunter.com/wilds/en-us/topics/unauthorized-modification-data/>

Both policies can change with a patch. Record the URL and date in the target's field note.

## Risk tiers

| Tier | Route | Typical risk | Minimum check |
|---|---|---|---|
| 1 | Official mod support, curated workshop, official asset tools | Lowest | The game's own terms and the tool's supported version |
| 2 | Cosmetic client-side asset swap, no gameplay effect, no memory injection | Tolerated by some games; account risk remains | Current policy names the method or is silent; mod is reversible |
| 3 | Cosmetic result delivered by injection, ASI, DLL proxy or memory patch | May trigger anti-cheat even when the visual result is harmless | Policy does not name the method; accept that detection is possible |
| 4 | Competitive advantage, economy change, DLC unlock, hitbox/visibility/audio/recoil change | Prohibited in practice | Do not ship |

Tier 2 is the only tier where "tolerated" is a reasonable word, and even there it is a policy observation with a date, not a guarantee.

## Decision checklist

1. Link the current official policy and record its date.
2. Does the policy name the delivery method (ASI, injection, pak, loose file)?
3. Does the mod change hitboxes, visibility, recoil, audio, model scale, drop rates or ownership? If yes, it is Tier 4.
4. Is there an official loader or asset path? Prefer it over injection.
5. Can the user revert it cleanly, with saves and original files backed up?
6. Has the user accepted the account risk in writing in the field note? Never assume it.

## Detection surfaces (high level)

Anti-cheat may check file integrity, loaded modules and signatures, memory regions, server-side state and player reports. A cosmetic mod can still be flagged if its delivery method resembles a cheat loader or if another player reports it. The reliable way to reduce risk is to avoid the behaviors the policy names, use supported asset paths, and keep the change cosmetic; there is no guaranteed undetected method, and this project does not claim one. Community reports of a cosmetic mod running without a ban are anecdotal and patch-specific; they do not establish a safe method.

## If a policy changes

Update this page with the new URL and date, update the target's field note, and add a `CHANGELOG.md` line. If a previously tolerated method becomes prohibited, move it to Tier 4 rather than arguing with the new text.
