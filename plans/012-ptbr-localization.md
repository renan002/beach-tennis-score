# Plan 012: Localize the apps to Brazilian Portuguese via a String Catalog

> **Correction (applied at execution, 2026-07-16)**: this plan's premise —
> "no strings files exist anywhere, so every user sees English" — was **false**.
> `iOS/pt-BR.lproj/Localizable.strings` and `watchOS/pt-BR.lproj/Localizable.strings`
> shipped from the initial commit (`a9c8eae`), wired into both targets' Resources
> phases. The work was therefore a **migration**, not a greenfield creation:
> a String Catalog cannot co-exist with a same-named `.strings` table (the watch
> build fails outright), so the legacy files were deleted and the catalog was
> seeded from **their** wording, then reconciled against the table below with the
> maintainer deciding each divergence. Adopted from this plan: `Ajustes`,
> `Fim de Jogo!`, `Vários`, `Cores dos Times`, `App do Watch não instalado`.
> Kept from the shipped strings instead: `Done` = `Concluído`, and
> `Team A`/`Team B` = `Time A (Nós)`/`Time B (Eles)` — the us/them framing is
> deliberate (the watch's owner is Team A), which this plan's table would have
> silently dropped. Also kept: `Game %lld` = `Set %lld`, the mapping the beach UI
> depends on (see `CLAUDE.md`) — this plan wrongly called it a no-op needing no
> entry. Entry count is 43, not 42. Treat the table below as historical;
> `Shared/Localizable.xcstrings` is the truth.

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 5497f0b..HEAD -- BeachTennisCounter/Shared/MatchState.swift BeachTennisCounter/iOS/Views BeachTennisCounter/watchOS/Views BeachTennisCounter/project.yml`
> Plans 005/008/010/011 legitimately touch these view files — this plan should
> land LAST among them. Diff the specific excerpts below against live code; a
> mismatch in the *strings themselves* (changed/removed user-facing text) is a
> STOP condition; surrounding structural changes from those plans are expected.

## Status

- **Priority**: P3
- **Effort**: M
- **Risk**: LOW (a wrong key shows untranslated English, never a crash)
- **Depends on**: none (soft: plan 001 for the test gate; land after 005, 008, 010, 011 to avoid merge conflicts in the view files)
- **Category**: direction
- **Planned at**: commit `5497f0b`, 2026-07-12
- **Issue**: https://github.com/renan002/beach-tennis-score/issues/12

## Why this matters

The project already declares the intent: `project.yml:10-13` lists `pt-BR` in
`knownRegions`, and `Team.displayName` routes through `NSLocalizedString`
(`MatchState.swift:8-10`) — but no strings files exist anywhere, so every user
sees English. The repo name ("contador") and maintainer locale say the primary
audience is Brazilian. One String Catalog in `Shared/` (compiled into both
targets) plus a handful of `String(localized:)` conversions delivers the
undelivered half.

## Current state

### How SwiftUI localization works here (primer — load-bearing)

- `Text("New Match")`, `Button("Done")`, `Label("All", ...)`,
  `.navigationTitle("History")`, `.alert("Cancel Match?", ...)` take
  `LocalizedStringKey` → **automatically** looked up in the catalog. No code
  change needed; only a catalog entry.
- Interpolations produce format keys: `Text("\(name) wins")` → key `%@ wins`;
  `Text("Version \(appVersion)")` → key `Version %@`. The catalog entry's key
  is the literal format string.
- **Plain `String`s do NOT localize**: computed vars returning `String`
  (`MatchType.displayName`, `SettingsView.sportSettingFooter`,
  `MatchListView.filterLabel`) and **ternaries of string literals**
  (`Text(cond ? "Tennis" : "Beach")` — the ternary infers `String`, so `Text`
  uses its verbatim init). These need `String(localized:)`.
- Missing catalog entries fall back to the key (English) — so only strings
  whose pt-BR differs from English need entries.

### Files with user-facing strings (all sites this plan covers)

- `Shared/MatchState.swift:7-11` — `Team.displayName` via `NSLocalizedString`
  (works with the catalog as-is; keys `Team A` / `Team B`);
  `MatchState.swift:18-23` — `MatchType.displayName` returns plain `String`:

```swift
var displayName: String {
    switch self {
    case .beachTennis: return "Beach Tennis"
    case .tennis: return "Tennis"
    }
}
```

- `watchOS/Views/HomeView.swift:33` — `Text("New Match")`; (if plan 011 landed:
  `Label("Resume Match", ...)`).
- `watchOS/Views/ServeSelectionView.swift:15` — `Text("Who serves first?")`;
  `teamButton` labels are `LocalizedStringKey` (`"Team A"`/`"Team B"`).
- `watchOS/Views/MatchTypeSelectionView.swift:16` — `Text("Select Sport")`.
- `watchOS/Views/ScoreView.swift:50-52, 221-239` — `"Cancel Match?"`,
  `"End Match"`, `"Keep Playing"`, `"Match Over!"`,
  `Text("\(state.winner?.displayName ?? "") wins")` (key `%@ wins`), `"Done"`.
- `watchOS/Views/MatchHistoryView.swift:10, 32` — `Text("Game \(...)")` (key
  `Game %lld` — same word in pt-BR, no entry needed), `.navigationTitle("History")`.
- `iOS/Views/MatchListView.swift` — `"Score Counter"` (:33), `"All"` /
  `"Beach Tennis"` / `"Tennis"` labels (:56-63), `filterLabel` (**plain
  String**, :74-80), `"Watch app not installed"` (:90), `"No matches yet"`
  (:107), `"Open the app on your Apple Watch to start a match"` (:110),
  `Text("A \(match.scoreDisplay) B")` (key `A %@ B` — no entry needed),
  `sportBadge` **ternary** `Text(match.matchType == .tennis ? "Tennis" : "Beach")`
  (:152), `Text("Team \(match.winner.uppercased()) wins")` (key `Team %@ wins`, :165).
- `iOS/Views/MatchDetailView.swift` — section/row labels `"Result"`,
  `"Sport"`, `"Score"`, `"Winner"`, `Text("Team \(...)")` (key `Team %@`),
  `"Details"`, `"Date"`, `"Duration"`, `"Sets"`, `"Games"`,
  `"Match Details"` (:67), `"Set \(...)"` / `"Game \(...)"` / `"Tiebreak"` /
  `"TB"` (Set/Game/Tiebreak/TB unchanged in pt-BR — no entries).
- `iOS/Views/SettingsView.swift` — `"Modality"`, `"Beach Tennis"`, `"Tennis"`,
  `"Multiple"` (:24-28), `"Sport"` (:31), footer strings via
  `sportSettingFooter` (**plain String**, :82-88), `"Team Colors"`,
  `"Team A"`, `"Team B"` (:36-38), `"Appearance"`, `"Theme"`, `"System"`,
  `"Light"`, `"Dark"` (:41-47), `"Settings"` (:50), `"Done"` (:54),
  `Text("Version \(appVersion)")` (key `Version %@`, :73).

### Deliberately NOT localized

Scoreboard glyphs and universal tennis vocabulary — same in pt-BR: `A`, `B`,
`TB`, `GP`, `Ad`, `40` etc., `Sets`, `Games`, `Game %lld`, `Set %lld`,
`Tiebreak`, `Beach Tennis` (the sport is called "Beach Tennis" in Brazil),
`Beach` (badge), `A %@ B`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Catalog JSON lint | `python3 -m json.tool BeachTennisCounter/Shared/Localizable.xcstrings > /dev/null` | exit 0, no output |
| Regenerate project | `cd BeachTennisCounter && xcodegen generate` | `Generated project at ...` |
| Watch build (compiles catalog) | `cd BeachTennisCounter && xcodebuild -target BeachTennisCounterWatch -sdk watchsimulator build` | `** BUILD SUCCEEDED **` |
| Built-product check | `ls BeachTennisCounter/build/Debug-watchsimulator/BeachTennisCounterWatch.app/pt-BR.lproj/` | contains `Localizable.strings` |
| Full test gate (compiles iOS) | see "Verified commands" in `plans/README.md` (from plan 001) | `** TEST SUCCEEDED **` |

## Scope

**In scope** (the only files you should modify/create):
- `BeachTennisCounter/Shared/Localizable.xcstrings` (create)
- `BeachTennisCounter/Shared/MatchState.swift` (`MatchType.displayName` only)
- `BeachTennisCounter/iOS/Views/MatchListView.swift` (`filterLabel`, `sportBadge` only)
- `BeachTennisCounter/iOS/Views/SettingsView.swift` (`sportSettingFooter` only)
- `BeachTennisCounter/BeachTennisCounter.xcodeproj/*` (regenerated — do not hand-edit)

**Out of scope** (do NOT touch):
- `CFBundleDisplayName` ("Beach Tennis Score") — localizing the app name needs
  an `InfoPlist.xcstrings` per target; deferred.
- `ScoreEngine.swift`, session managers, `privacy-policy.md`.
- Adding more languages, or `Locale`-aware date/number formatting changes
  (`.formatted()` already localizes dates automatically).
- Rewriting `Team.displayName`'s `NSLocalizedString` to `String(localized:)` —
  it already resolves through the catalog; churn without benefit.

## Git workflow

- Branch: `advisor/012-ptbr-localization`
- Commit style: `feat(l10n): Brazilian Portuguese localization via String Catalog`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Create the String Catalog

Create `BeachTennisCounter/Shared/Localizable.xcstrings`. It is a JSON file
with this exact schema — here are three fully worked entries (plain, format
string, and long sentence):

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "New Match" : {
      "localizations" : {
        "pt-BR" : {
          "stringUnit" : { "state" : "translated", "value" : "Nova Partida" }
        }
      }
    },
    "%@ wins" : {
      "localizations" : {
        "pt-BR" : {
          "stringUnit" : { "state" : "translated", "value" : "%@ venceu" }
        }
      }
    },
    "The Watch will ask which sport before each match." : {
      "localizations" : {
        "pt-BR" : {
          "stringUnit" : { "state" : "translated", "value" : "O Watch perguntará qual esporte antes de cada partida." }
        }
      }
    }
  },
  "version" : "1.0"
}
```

Create **one entry per row** of this table, following that pattern exactly
(the key is the left column, byte-for-byte — including `?`, `!`, `%@`):

| Key (en) | pt-BR value |
|---|---|
| `New Match` | `Nova Partida` |
| `Resume Match` | `Retomar Partida` |
| `Who serves first?` | `Quem saca primeiro?` |
| `Team A` | `Time A` |
| `Team B` | `Time B` |
| `Select Sport` | `Escolha o Esporte` |
| `Match Over!` | `Fim de Jogo!` |
| `%@ wins` | `%@ venceu` |
| `Done` | `OK` |
| `Cancel Match?` | `Cancelar Partida?` |
| `End Match` | `Encerrar Partida` |
| `Keep Playing` | `Continuar Jogando` |
| `History` | `Histórico` |
| `Score Counter` | `Placar` |
| `All` | `Todos` |
| `Tennis` | `Tênis` |
| `Watch app not installed` | `App do Watch não instalado` |
| `No matches yet` | `Nenhuma partida ainda` |
| `Open the app on your Apple Watch to start a match` | `Abra o app no seu Apple Watch para começar uma partida` |
| `Team %@ wins` | `Time %@ venceu` |
| `Team %@` | `Time %@` |
| `Match Details` | `Detalhes da Partida` |
| `Result` | `Resultado` |
| `Sport` | `Esporte` |
| `Score` | `Placar` |
| `Winner` | `Vencedor` |
| `Details` | `Detalhes` |
| `Date` | `Data` |
| `Duration` | `Duração` |
| `Settings` | `Ajustes` |
| `Modality` | `Modalidade` |
| `Multiple` | `Vários` |
| `Team Colors` | `Cores dos Times` |
| `Appearance` | `Aparência` |
| `Theme` | `Tema` |
| `System` | `Sistema` |
| `Light` | `Claro` |
| `Dark` | `Escuro` |
| `Version %@` | `Versão %@` |
| `The Watch will always start a Tennis match.` | `O Watch sempre iniciará uma partida de Tênis.` |
| `The Watch will ask which sport before each match.` | `O Watch perguntará qual esporte antes de cada partida.` |
| `The Watch will always start a Beach Tennis match.` | `O Watch sempre iniciará uma partida de Beach Tennis.` |

(Include `Resume Match` even if plan 011 hasn't landed — an unused entry is
harmless.)

**Verify**: `python3 -m json.tool BeachTennisCounter/Shared/Localizable.xcstrings > /dev/null` → exit 0; `grep -c "stringUnit" BeachTennisCounter/Shared/Localizable.xcstrings` → 42.

### Step 2: Register the catalog and confirm it builds as a resource

Run `cd BeachTennisCounter && xcodegen generate`. XcodeGen picks up new files
under each target's `sources` paths and infers the resources build phase for
`.xcstrings`.

**Verify**: `grep -c "Localizable.xcstrings" BeachTennisCounter/BeachTennisCounter.xcodeproj/project.pbxproj` → ≥ 2 (file ref + build files). Then run the watch build → `** BUILD SUCCEEDED **`, and the built-product check → `pt-BR.lproj/Localizable.strings` exists.

### Step 3: Convert the four plain-String sites

1. `Shared/MatchState.swift` — `MatchType.displayName`:

```swift
var displayName: String {
    switch self {
    case .beachTennis: return String(localized: "Beach Tennis")
    case .tennis: return String(localized: "Tennis")
    }
}
```

2. `iOS/Views/MatchListView.swift` — `filterLabel`:

```swift
private var filterLabel: String {
    switch filter {
    case "beachTennis": return String(localized: "Beach Tennis")
    case "tennis":      return String(localized: "Tennis")
    default:            return String(localized: "All")
    }
}
```

3. `iOS/Views/MatchListView.swift` — `sportBadge`'s first line:

```swift
Text(match.matchType == .tennis ? String(localized: "Tennis") : "Beach")
```

4. `iOS/Views/SettingsView.swift` — `sportSettingFooter`: wrap each of the
   three returned literals in `String(localized:)`, keeping the strings
   byte-identical to the table keys above.

**Verify**: `grep -c "String(localized:" BeachTennisCounter/Shared/MatchState.swift BeachTennisCounter/iOS/Views/MatchListView.swift BeachTennisCounter/iOS/Views/SettingsView.swift` → 2, 4, 3 respectively.

### Step 4: Full gate

Run the verified test command (compiles the iOS target and its catalog).

**Verify**: `** TEST SUCCEEDED **`; then
`ls BeachTennisCounter/build/Debug-watchsimulator/BeachTennisCounterWatch.app/pt-BR.lproj/`
still shows `Localizable.strings`.

## Test plan

No unit tests — localization has no logic seam here, and asserting on
`String(localized:)` in the test bundle tests the test host's locale, not the
apps. Gates: JSON lint, entry count (42), the two builds, and the built
`pt-BR.lproj` check. Manual QA for the operator: set an iOS simulator to
Português (Brasil) → Settings screen shows "Ajustes / Modalidade / Aparência";
watch simulator in pt-BR → "Nova Partida", and a finished match shows
"Fim de Jogo!" with "Time A venceu".

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `python3 -m json.tool BeachTennisCounter/Shared/Localizable.xcstrings > /dev/null` → exit 0
- [ ] `grep -c "stringUnit" BeachTennisCounter/Shared/Localizable.xcstrings` → 42
- [ ] Watch build → `** BUILD SUCCEEDED **`; built app contains `pt-BR.lproj/Localizable.strings`
- [ ] Test command → `** TEST SUCCEEDED **`
- [ ] `grep -rn '"Multiple"' BeachTennisCounter/iOS/Views/SettingsView.swift` still matches (Picker tags/keys unchanged — only footers were wrapped)
- [ ] `git status` shows changes only to in-scope files (plus regenerated `.xcodeproj`)
- [ ] `plans/README.md` status row updated

## STOP conditions

Stop and report back (do not improvise) if:

- After `xcodegen generate`, `Localizable.xcstrings` lands in a **compile
  sources** phase or the watch build fails on the catalog — the installed
  XcodeGen predates `.xcstrings` support. Report it (likely fix is an XcodeGen
  upgrade or an explicit `buildPhase: resources` source entry — a maintainer
  decision, not yours).
- The built app has no `pt-BR.lproj/` despite a green build.
- Any user-facing string in the code no longer matches the table keys
  byte-for-byte (drift from plans 005/008/010/011) — update the catalog key to
  match the *live* code only if the meaning is identical; otherwise stop.
- You are tempted to change the `Picker` **tag values** (`"beachTennis"`,
  `"tennis"`, `"multiple"`) or any `UserDefaults`-persisted string — those are
  storage keys, not display text; translating them breaks settings.

## Maintenance notes

- New user-facing strings must get a catalog entry or they'll silently ship
  English-only; cheapest check in review: any new `Text("...")` with
  translatable English should have a matching key in `Localizable.xcstrings`.
- Keys are the English source strings — if UI copy is reworded, the catalog
  entry must be re-keyed in the same commit (a stale key = silent fallback to
  the new English text).
- Deferred follow-ups: localized `CFBundleDisplayName` (InfoPlist.xcstrings),
  localizing the App Store metadata / privacy policy, and deciding whether
  "Done" should be "OK" vs "Concluído" on iOS (this plan uses "OK" everywhere
  for watch-screen fit; both are acceptable pt-BR).
