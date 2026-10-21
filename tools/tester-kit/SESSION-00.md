# Session S0 — setup and first link test

| | |
|---|---|
| **Goal** | (1) REFramework, the probe and the mod test build work on both PCs. (2) A private Link Party works between our two countries. (3) The mod's own connection works between our PCs (Phase 2 check). (4) Find out whether **Environment Link** (exploring together) is available at our current story point, and what happens to it when one of us starts a story assignment. |
| **Length** | About 30–45 minutes, live on a voice call. Possibly followed by solo "homework" (see Part 4). |
| **Kit** | Tester kit v0.2 (REFramework + read-only probe 0.1.3 + Seamless Co-op test build 0.1.0-dev). Developer: the same probe and test build (`tools/deploy.ps1 -Probe -Mod`), `dev_selftest` off. |
| **Characters** | Both on the **test character**. Story point: Chapter 1-2. **"Back to Camp" is finished** (the game has put you in an online lobby) and the next assignment, **"The Beginning"**, is shown but not played yet. |

> Assignment names below are the English ones. If your game is in another language, use the chapter numbers instead
> (for example *Chapter 1-3*).

## Before the call (tester)

1. Install the kit if you haven't yet (`README-TESTER.md`), and check that it works.
2. Make sure the developer is on your Steam friends list.
3. Have a way to take screenshots (the Steam overlay's F12 works), or just write down any messages you see.

## Part 1 — Check (5 min)

| Step | Developer (PC-A) | Tester (PC-B) |
|---|---|---|
| 1.1 | Start the game, load "Test". Check that the probe shows 0.1.3. | Start the game, load your **test character**. Insert > *Script Generated UI* > *Seamless Co-op probe 0.1.3*: note the **Hooks** line. Close with Insert. |
| 1.2 | Count down "3, 2, 1, mark". | On "mark", press **F8** at the same time as the developer. You should see *"Probe: mark #1 saved"*. |

This first shared mark lets us line up the two logs later.

## Part 2 — Link Party (10 min)

| Step | Developer (PC-A) | Tester (PC-B) |
|---|---|---|
| 2.1 | Create a **private** Link Party and invite the tester. Guide the tester through the menus on the call. | Accept the Link Party invitation. **F8** when you're in the party. |
| 2.2 | Both go to the same base camp. If you can't see each other, join the same lobby too (one player joins the other's lobby). | Say whether you can see the developer's character. |
| 2.3 | Try to start **Environment Link** with the tester. **F8** right before. | **F8** when the developer says. Write down any message exactly (or screenshot it). |

**Expected:** the Link Party works. Environment Link may be **refused** at this story point: the game introduces it a
little later, in Chapter 1-3 ("To the Forest"). A refusal is a useful result too.

## Part 2b — Seamless Co-op connection (5 min)

You need to be Steam friends and in the same Link Party for this.

| Step | Developer (PC-A) | Tester (PC-B) |
|---|---|---|
| 2b.1 | Insert > Script Generated UI > **Seamless Co-op** > **Link Party**. Read out what it says about the tester. | Same: what does it say next to the developer's name? Expected: `modded - compatible - <number> ms`. |
| 2b.2 | Press **Ctrl+F12** (mod off). **F8**. | Within a few seconds the developer should show `mod turned off`. **F8** when you see it. |
| 2b.3 | Press **Ctrl+F12** again (mod on). | The developer goes back to `modded - compatible`. |
| 2b.4 | Watch the tester's line. | Now you press **Ctrl+F12** twice (off, wait 5 seconds, on). |

If it says `not a Steam friend in game (no side channel)` or stays at `no reply yet`, take a screenshot. That's
useful too, so don't spend more than 5 minutes on it.

## Part 3 — only if Environment Link worked (15–20 min)

| Step | Developer (PC-A) | Tester (PC-B) |
|---|---|---|
| 3.1 | Stand near the tester. Both **F8**. | Stand near the developer. Both **F8**. |
| 3.2 | Start the assignment **"The Beginning"** (follow the marker / talk to the NPC). **F8** right when it starts. | **Don't start anything yet.** F8 when the developer starts. Watch: does the developer vanish? Does a message appear? Are you still in the Link Party? |
| 3.3 | Keep playing your assignment for a few minutes. | Now start **"The Beginning"** yourself. **F8** when it starts. Tell the developer what you see. |
| 3.4 | Both play on to the end of "The Beginning", then **stop**. Both **F8**. | Same. |

If at any point you two are separated, just carry on alone up to the end of "The Beginning". Then skip to Part 5.

## Part 4 — if Environment Link was refused: catch-up homework (solo, ~30 min each, any time)

Each of us plays **alone** with the probe running (no need to be on a call):

1. Play the story through **"The Beginning"**, **"Village of Whispering Winds"** (includes the *Quematrice* hunt) and
   **"To the Forest"** (Chapter 1-3). "To the Forest" introduces Environment Link.
2. **Stop as soon as the next assignment, "Forest Findings", appears.** Don't start it: it's the next test.
3. Cutscenes: watch or skip as you like. If you remember, press **F8** at the start and end of each cutscene and
   whenever something "story" happens (a conversation starts, you're asked to follow someone, a monster appears). It's
   fine to forget.
4. Close the game and run `collect-logs.cmd`. Send the zip.

The next session (S0b) then repeats Parts 2–3 at "Forest Findings": Environment Link while one of us starts the
assignment, and the *Lala Barina* hunt joined the normal (unmodded) way.

## Part 5 — wrap up (5 min)

1. Both close the game.
2. Tester: run **`collect-logs.cmd`** and send the zip on your Desktop. Developer: copy the trace from
   `reframework\data\seamless_coop\traces\`.
3. Tester: copy the checklist below into a message and fill it in.

```
S0 checklist
- Probe line after start (Hooks: ... ok, ... failed): 
- Seamless Co-op panel: game build line, save backup line: 
- Link Party worked (yes/no): 
- Mod connection (Part 2b): what the panel said about the developer; did off/on show up on the other side? 
- Could see the developer's character before Environment Link (yes/no/where): 
- Environment Link: worked / refused. Exact message (or screenshot): 
- If it worked: what happened when the developer started "The Beginning"? 
- If it worked: what happened when you started it too? 
- Anything odd (lag, crashes, strange menus): 
- Time spent: 
```

## Developer notes (not for the tester)

- Part 2b is the Phase 2 exit check. Both `logs\session-N.log` should show `party: 2 member(s), 1 friend(s) in game,
  1 matched by name` (or `paired by fallback`, which means `OnlineId` isn't the Steam persona name: note it in
  game-model §4.1), then `peer ...xxxx: pending -> compatible`. Kill switch: `-> left` on the other side, then back to
  `compatible`. The tester's first launch also logs a `selftest:` line (the kit enables `dev_selftest`). Its
  `steam_self=compatible` result proves their Steam relay path works on its own.

- Align traces by the Part 1 shared mark (`k = "mark"`, `utc` field) and look at the marks between steps.
- R6 questions: does `Net_Party.leaveLinkPartySync(…, LEAVE_StoryEvent)` fire on the starter's PC, the joiner's PC, or
  both? What do `getCanPartySyncInfoInCurrentStage` and `setPartySyncInfo` do for `001042`/`001045`? Is
  `isEnableJoinAcceptPartySync` checked against the party-sync progress (`PartySyncProgressDatas`, 0 at this point)?
- If Environment Link is refused at progress 250, record which method refuses it (look for the last `Net_Party` /
  `NetworkRequestManager` calls before the refusal UI) and the message ID if one is logged.
- After this session, update `docs/re/game-model.md` §3 and the session plan in `docs/testing/remote-testing.md`.
