# Czech fork of GarminRosary

Fork of [DevMc120/GarminRosary](https://github.com/DevMc120/GarminRosary), published as
**Růženec** in the Connect IQ Store:
https://apps.garmin.com/en-US/apps/c7a5d79f-b3ab-45fb-a62e-5e59af395d9c
(own name, icon and app id, as README.md asks of published forks).

## What differs from upstream

- **Czech regardless of the watch language, Slovak on Slovak watches.** `monkey.jungle` appends
  `resources-ces` (and the fork strings) to the default resource path; later paths win, so all
  mysteries, prayers and menus are Czech even on an English watch. No upstream string file is
  edited. A watch set to Slovak gets `resources-slo` instead (`base.lang.slo`), which holds every
  string id of `resources-ces` and `resources-fork`; a missing id would quietly show Czech. The
  manifest lists Czech and Slovak only, so device variants without that firmware (Asia-Pacific
  editions) are not built.
- **Slovak texts** (`resources-slo/strings/strings.xml`, sources in its header): Creed from the
  Jednotný katolícky spevník, Salve Regina from the Slovak Liturgy of the Hours, mysteries and intro
  petitions as published with the KBS wording, the closing prayer from the Slovak Dominicans'
  collect for Our Lady of the Rosary, Bible quotations from the SSV 1996 translation. Meditations,
  menus, help and the fruits of the mysteries are translated and need a Slovak proofreader. The main
  screen shows the KBS-approved (2003) short luminous mysteries, the meditation view the full ones.
- **Intro petitions per set of mysteries.** The three introductory Hail Marys show the petition of
  the current set (`GarminRosaryView.getIntroPetition`, strings `intro_<set>_1..3`). Slovak has a
  different trio for each set; the Czech strings repeat Víra / Naděje / Láska.
- **Long mystery titles fit the decade screen.** A title that would take three lines on a round
  screen gets the smaller font, then the `_title_short` variant
  (`RosaryModel.getCurrentMysteryShortTitle`); likewise more than three lines on rectangular screens
  and a second line too wide on the Instinct 2. Upstream's `drawWrappedText` line breaking moved to
  `getWrappedLines` for this. The prayer text view drops to the body font when its title is wider
  than a round screen.
- **Full texts of the long prayers.** Věřím v Boha, Zdrávas Královno and Modleme se open
  automatically as a paged text (`source/fork/PrayerTextView.mc`). DOWN / swipe up = next page,
  UP / swipe down = previous page, START / tap = continue with the next prayer, BACK = close only
  (swipe up or hold START on the main screen reopens it).
  Texts are in `resources-fork/strings/strings.xml`, one phrase per line, taken from
  [pastorace.cz](https://www.pastorace.cz/tematicke-texty/modlitba-ruzence-krok-za-krokem).
- **Backlight stays on while a long prayer text is shown** (`Attention.backlight`, refreshed every 2 s,
  for at most 3 minutes; devices that refuse to hold the display on, such as AMOLED ones with burn-in
  protection, simply stop the refresh).
- **No unnecessary last scroll.** If a prayer text would end with a page of only one or two lines, the
  layout is retried with slightly wider rows and tighter line spacing (see `PrayerTextView.onLayout`).
- **Swipe left skips to the next Our Father** (`RosaryModel.skipToNextOurFather`): the remaining Hail Marys
  are skipped, for praying them without counting. It stops at the Salve Regina, the closing prayer and
  the mystery transition of the full rosary. The in-app help (`help_text` in `resources-fork`) mentions it.
  There is no button gesture yet: hold DOWN was left out because it could not be tested without the buttons.
- **Fatima prayer after the Glory Be of every decade** (not after the one in the introduction). It is
  part of the same step, so bead counts, progress and the number of presses are unchanged: the decade's
  Glory Be screen shows "Pane Ježíši" under "Sláva Otci", in the line where the Hail Mary screens name
  their prayer (`GarminRosaryView.drawDecadeScreen`). Name only, like the other short prayers; the full
  text is in `prayer_fatima_text` but not shown, because hold / swipe up on that screen opens the
  decade's meditation.
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
- `manifest.xml` language list: keep `ces` and `slo` only.
- `help_text` in `resources-fork/strings/strings.xml` repeats upstream's Czech help plus the swipe-left
  line: if upstream changes its help, merge the change by hand (and into `resources-slo`).
- New string ids upstream (in `resources-ces`) must also be added to `resources-slo`, or Slovak
  watches show them in Czech. Compare the id lists of both files after each merge.
- `GarminRosaryView.drawWrappedText`: its body moved to `getWrappedLines`; apply upstream changes there.

Slovak tests: build with a throwaway jungle (outside the repo) whose `base.resourcePath` ends with
`resources-slo`, so the simulator shows Slovak whatever its language setting.
