# Czech fork of GarminRosary

Personal, sideloaded fork of [DevMc120/GarminRosary](https://github.com/DevMc120/GarminRosary).
Not published to the Connect IQ Store (see the name/icon note in README.md).

## What differs from upstream

- **Czech regardless of the watch language.** `monkey.jungle` appends `resources-ces` (and the
  fork strings) to the default resource path; later paths win, so all mysteries, prayers and menus
  are Czech even on an English watch. No upstream string file is edited. The manifest lists Czech
  as the only language, so the store shows Czech, and device variants without Czech firmware
  (Asia-Pacific editions) are not built.
- **Full texts of the long prayers.** Věřím v Boha, Zdrávas Královno and Modleme se open
  automatically as a paged text (`source/fork/PrayerTextView.mc`). DOWN / swipe up = next page,
  UP / swipe down = previous page, START / tap = continue with the next prayer, BACK = close only
  (swipe up or hold START on the main screen reopens it).
  Texts are in `resources-fork/strings/strings.xml`, one phrase per line, taken from
  [pastorace.cz](https://www.pastorace.cz/tematicke-texty/modlitba-ruzence-krok-za-krokem).
- **Zdrávas Královno and Modleme se are actually prayed.** Upstream defines `STATE_SALVE` but goes
  from the last Sláva Otci straight to "complete"; the fork inserts both before the end.
- **Own app id** in `manifest.xml`, so the fork does not collide with the store app.
- **Own icon** (linden leaf as a heart inside a rosary): the upstream name and logo are not
  covered by the GPL. `store/icons.py` renders the launcher icon into `resources-fork/drawables`
  (overriding upstream's `LauncherIcon`) and the store icons into `store/`.
- **Store listing** texts and screenshots are in `store/`.
- **Build fix.** Upstream `MeditationView.mc` uses `DeviceProfile`, `Palette` and `RosaryConstants`,
  which were never committed; `source/fork/UpstreamShims.mc` provides stand-ins.

Changes inside upstream files are marked with `FORK:` comments.

## Build and sideload

```sh
monkeyc -f monkey.jungle -d fenix7x -r -y ~/.Garmin/personal_developer_key.der -o bin/Ruzenec.prg
```

Connect the watch over USB and copy `bin/Ruzenec.prg` to `GARMIN/APPS/`.

Store package (all devices in the manifest). Always sign with the same key, otherwise the store
rejects the update:

```sh
monkeyc -f monkey.jungle -e -r -y ~/.Garmin/personal_developer_key.der -o bin/Ruzenec.iq
```

Tests (simulator must be running):

```sh
monkeyc -f monkey.jungle -d fenix7x -t -y ~/.Garmin/personal_developer_key.der -o bin/test.prg
monkeydo bin/test.prg fenix7x /t
```

## Pulling upstream updates

```sh
git fetch upstream
git merge upstream/main
```

Expected conflicts:

- `manifest.xml`: upstream version bumps touch the same line as the app id. Keep the fork's id,
  take upstream's version.
- If upstream commits the real `DeviceProfile` / `Palette` / `RosaryConstants`, the build reports
  duplicate definitions: delete `source/fork/UpstreamShims.mc`.
- `manifest.xml` language list: keep `ces` only.
