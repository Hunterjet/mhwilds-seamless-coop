# Seamless Co-op — tester kit v0

Thank you for helping! This kit prepares your game for our test sessions. It installs two things:

1. **REFramework**: a widely used mod loader for Capcom games (it's a file called `dinput8.dll` in the game folder).
2. **The research probe**: a small script that **only watches** what the game does during co-op and writes it to a log file.
   It **never changes** the game, your saves, your quests or your rewards.

The kit also makes a **backup copy of your save files** first, just in case. It never edits them.

## Before you start

- **Account risk.** Any mod in an online game carries a small risk. Capcom has suspended players for *changing quest
  data*. This kit doesn't change anything, it only watches. Still, we can't promise zero risk. If you're not
  comfortable with that, please don't install it, and that's completely fine.
- **Use your test character** (the one in the spare save slot), not your main character.
- It takes about 5 minutes. You need an internet connection; the kit downloads REFramework (13 MB) from GitHub.

## Install

1. **Close Monster Hunter Wilds** completely.
2. Download the kit zip (`seamless-coop-tester-kit-v0.zip`) from the link the developer sent you.
3. Right-click the zip > **Extract All...** > **Extract**. (Don't run the files from inside the zip.)
4. Open the extracted folder and double-click **`install.cmd`**.
   - If Windows says **"Windows protected your PC"**: click **More info**, then **Run anyway**. Windows shows this for
     any new script downloaded from the internet.
   - If Windows asks **"Do you want to allow this app to make changes to your device?"**: click **Yes**. (This only
     happens if your game folder is protected.)
5. Wait until it says **"All done!"**, then press Enter.

**If it says it can't find the game:** in Steam, right-click *Monster Hunter Wilds* > *Manage* > *Browse local files*.
Click the address bar of the window that opens and copy the folder path. Then open the kit folder, click its address bar,
type `cmd` and press Enter. In the black window type `install.cmd "` + paste the path + `"` and press Enter. Example:

```
install.cmd "D:\SteamLibrary\steamapps\common\MonsterHunterWilds"
```

**If it says your game version is different:** stop and tell the developer. A new kit is needed after game updates.

## Check that it works

1. Start the game from Steam as usual. The first start can take a little longer.
2. Load your **test character**.
3. Press **Insert** on your keyboard. The REFramework menu opens.
4. Open **Script Generated UI** > **Seamless Co-op probe 0.1.3**. It should say something like
   `Hooks: 360 ok, 0 failed`. If it shows *NOT WRITING* or *failed* hooks, take a screenshot for the developer.
5. Press **Insert** again to close the menu.
6. Press **F8** once. A small white message appears in the top-left corner: *"Probe: mark #1 saved"*. 

**F8 = bookmark.** During sessions the developer will ask you to press F8 at certain moments. It just puts a bookmark in
the log so we can find those moments later. Pressing it too often or at the wrong time is no problem.

## After each session: send your logs

1. Close the game.
2. Double-click **`collect-logs.cmd`** in the kit folder.
3. It creates a zip on your **Desktop** called `seamless-coop-logs-<date>.zip`. Send that file to the developer.

The logs contain game function names and numbers only. The kit also removes your Windows user name, computer name and
Steam ID from them before zipping.

## Uninstall

Close the game and double-click **`uninstall.cmd`**. It removes the probe and puts back whatever `dinput8.dll` you had
before (or removes it if there was none). Your save backups and logs stay in
`<game folder>\reframework\data\seamless_coop\` until you delete that folder.

## Troubleshooting

| Problem | What to do |
|---|---|
| The game doesn't start, crashes, or shows a black screen for more than 3 minutes | Close it (Task Manager if needed), run `uninstall.cmd`, start the game again without mods, and tell the developer. |
| A black window opens and closes immediately | Right-click `install.cmd` > *Show more options* > *Run as administrator*. If that doesn't help, send a photo of the window. |
| You see a red **STOPPED:** message | Read it. It says what to do. Send a photo of the window to the developer if unsure. |
| You use other mods | Tell the developer which ones before the session. ReShade is fine. Other mods that use `dinput8.dll` are replaced (and backed up) by the kit. |
| You want your save backup | It's in `<game folder>\reframework\data\seamless_coop\save_backups\`. Ask the developer before restoring anything. |
