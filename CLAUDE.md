# CLAUDE.md

Czech fork of [DevMc120/GarminRosary](https://github.com/DevMc120/GarminRosary), published on the
Connect IQ Store as **Růženec**. Read `FORK.md` first: it lists every difference from upstream, the
build commands and the expected merge conflicts. `store/listing.md` has the store texts.

## Layout

- `source/` upstream code. Changes inside upstream files are marked `FORK:`.
- `source/fork/` fork-only code (prayer text view, unit tests, shims for upstream's missing classes).
- `resources-ces/` upstream's Czech strings, left untouched. `resources-fork/` fork strings, prayer
  texts and the launcher icon. `monkey.jungle` layers them so the app is Czech on any watch language.
- `resources-slo/` the complete Slovak string set (every id of the two above), used only when the
  watch language is Slovak. Sources are listed in its header.
- `store/` listing, icons, screenshots. `store/icons.py` renders the icons.
- `bin/` build output, untracked.

## Conventions

- Code comments and docs in English. Prayer names and texts stay Czech (Slovak in `resources-slo`).
- A new or changed string goes into both `resources-fork` (Czech) and `resources-slo` (Slovak).
  Slovak texts are proofread by a Slovak speaker before release.
- Binary files (PNG) are committed as plain files, no Git LFS.
- Commits use the repo-local identity (GitHub noreply address); do not change it to a work email.
- Prayer texts come from pastorace.cz, one phrase per line.
- The app is GPL-3.0. Keep the fork's own name, icon and app id (upstream's README asks for this).

## Build and test

SDK: `%APPDATA%\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.2.0-...` (`bin\monkeyc.bat`, `monkeydo.bat`).
Commands are in `FORK.md`. Sign only with `~/.Garmin/personal_developer_key.der`: the store rejects
updates signed with another key, and Garmin keeps no copy. `audic_developer_key.der` belongs to the
AUDIC apps.

- Unit tests (`source/fork/RosaryModelTest.mc`) need the simulator running:
  `monkeyc ... -d fenix7x -t` then `monkeydo bin/test.prg fenix7x /t`. Run them on several devices
  (fenix7x, fenix7s, venu3, instinct2, vivoactive4); the layout test uses a BufferedBitmap.
  Run them in Slovak too, built with a throwaway jungle that ends `base.resourcePath` with
  `resources-slo` (see `FORK.md`). In Git Bash, `/t` is mangled into a path: run monkeydo from
  PowerShell.
- Do not drive the simulator with keystrokes or mouse input while the user is at the computer: it
  steals focus. Reading the window pixels (PrintWindow) is fine.
- A visual check of a given screen needs a throwaway harness app that sets the model state and calls
  `setCurrentState` on the view; keep it outside the repo.

## Releasing

1. Bump `version` in `manifest.xml` (keep the app id and the `ces` + `slo` language list).
2. Build `bin/Ruzenec.iq` with `-e -r`, and `bin/Ruzenec.prg` for sideloading on the Fenix 7X.
3. Update `store/listing.md` if the features changed. The user uploads the `.iq` and pastes the
   texts at apps.garmin.com; ask before pushing to GitHub.
