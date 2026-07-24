# Beach Tennis Counter

Matches are scored live on the watch, point by point, and completed matches are
kept on the phone. (Truco is the one exception: it is also scored on the phone,
because it is played at a table, not on a court.) This glossary fixes the
language for that split — in particular for the three different things this
project has historically called "history".

## Language

### Matches

**Match**:
A single contest between two teams, from first point to final point. The unit a
player starts, scores, and finishes.

**Sport**:
The game being played — beach tennis, tennis, ping pong, or truco. A match has
exactly one, fixed at its start. The sport decides the scoring vocabulary, the
shape of the score screen, and whether the match is physical.
_Avoid_: mode, match type (in user-facing copy — `MatchType` is the type's name,
not the word)

**Placar**:
A live scoreboard: the screen where a match in progress is scored. Normally the
watch's, but truco is also scored on the phone. Each device owns at most one
live Placar; the two devices are never coordinated, and a match scored on either
lands in the same Match History.
_Avoid_: scoreboard, counter (in user-facing pt-BR copy)

**Team Name**:
The user-set label attached to side A or B of a match; empty means unnamed, and
the UI falls back to the localized "Team A"/"Team B". Stamped onto the match at
its start, so renaming in Settings never rewrites a match already played.
_Avoid_: player name, team label

**Match History**:
The durable collection of completed matches, kept on the phone. It is the only
lasting record of what a player has played — the watch keeps no record of past
matches.
_Avoid_: history, match list, backup

**Game Log**:
The sequence of games played within one match, recording who won each game and
at what score. Belongs to a single match and is meaningless outside it.
_Avoid_: history, game history

**Undo Stack**:
The earlier states of the match currently being scored, kept only so a player
can take back a point they entered by mistake. Discarded when the match ends.
_Avoid_: history

### Scoring units

**Game**:
The sport's scoring unit — the thing won, recorded in the Game Log, and counted
toward the match. A game in tennis and ping pong, a Mão in truco. Internally
always called a game in every sport (`GameRecord`, Game Log); only the label
shown to the player varies, and it comes from the sport.

**Mão**:
Truco's scoring unit: one deal, won by one side and worth its Stake. Recorded in
the Game Log as a Game, labelled "Mão N".
_Avoid_: rodada (a rodada is one of the three card-plays inside a mão, which the
app does not model), hand (in user-facing pt-BR copy)

**Stake**:
What a Mão is worth — 1 unless someone called truco, then 3, 6, 9, or 12. Not a
score: it is the multiplier the winner of the Mão collects.
_Avoid_: bet, points (for the stake itself)

**Set**:
In tennis, a real set — a collection of games. In beach tennis there are no
sets; the match is a single sequence of games, but the UI displays each beach
game as a "Set". This is the established Brazilian beach-tennis convention and
applies in every language, not just pt-BR.

> Display rule: the Game/Set label is a function of the sport, never of the
> locale. Beach tennis game-level labels read "Set N" in all languages; tennis
> reads "Game N" for games and "Set N" for sets in all languages ("game" and
> "set" are loanwords in pt-BR tennis).

> The truco terms above (**Mão**, **Stake**) are provisional pending the truco
> research ticket, which settles the regional vocabulary before any of it
> reaches the String Catalog.

**Headline Score**:
The single pair of numbers that stands for a match's result — in the match list,
the Cartão de Resultado, and above the live Placar. It is the highest scoring
level the sport has that the Ruleset leaves non-degenerate and that has a
completed unit on the board; otherwise the level below. So: sets in tennis,
games in beach tennis, games in a best-of-5 ping pong match, but *points* in a
best-of-1 ping pong match or a match abandoned in its first game, and points in
truco. Always derived, never a stored field of its own.
_Avoid_: final score, score (unqualified)

### Rules

**Ruleset**:
The rules a match is played under — how many points win a game, best of how many
games, how the serve rotates, what the match is played to. One per sport is
active at a time. A Ruleset is stamped by value onto a match at its start, name
included, so editing or renaming it later never rewrites a match already played.
User-facing: **Regras**.
_Avoid_: config, settings, options, rules (unqualified)

**Preset**:
A named Ruleset that ships with the app, standing for how a variant is actually
played ("Truco Paulista", "Ping pong ITTF"). Picking one is a single tap;
changing any knob turns it into a Custom Ruleset.
_Avoid_: template, default (a Preset may or may not be the default)

**Custom Ruleset**:
A Ruleset the player built and named themselves. Saved on the phone, listed
alongside the Presets, editable and deletable. Editing one never touches the
matches already stamped with it.
_Avoid_: personalizado (as the type's name — *Personalizado* is the UI label for
an unsaved Ruleset that no longer matches its Preset)

### Monetization

**Pro**:
The one-time lifetime unlock, purchased on the iPhone. Pro gates Estatísticas,
Vários, and removes the watermark from the Cartão de Resultado. Scoring is
never gated: every sport is playable for free, under any Ruleset, and the watch
app shows no purchase UI and no paywall — every Pro touchpoint lives on the
phone.
_Avoid_: premium, subscription, upgrade (as a noun)

**Vários**:
The sport-picker setting that makes the watch ask which sport before each
match, instead of playing the one sport fixed in the iPhone settings. A Pro
convenience: it gates comfort, never capability — a free player switches
sports by changing the setting on the iPhone.
_Avoid_: multiple mode, multi-sport (as user-facing copy)

**Estatísticas**:
Insights computed from the Match History (win rate, streaks, golden-point
conversion, per-partner records). A Pro feature; lives where the Match History
lives, on the phone.
_Avoid_: insights, stats (in user-facing pt-BR copy)

**Cartão de Resultado** (Result Card):
A shareable image of a completed match's result, made to be posted to social
media. Free for everyone, carrying a small app watermark; Pro removes the
watermark. The watermark is the app's advertisement, not a defect.
_Avoid_: screenshot, banner

### Store recovery

**Store**:
The place a Match History lives. There is exactly one live store at a time.

**Quarantined Store**:
A store the app could not open, set aside intact rather than deleted. Being
quarantined says only that the app could not read it — not that it is damaged.
The most likely cause is a store written by an older version of the app that a
newer version cannot yet read, in which case the contents are perfectly sound.
_Avoid_: backup, corrupt store, corrupted store

> "Backup" is deliberately avoided: on this platform it already means the
> device's own iCloud backup, which is a different thing that a Quarantined
> Store is explicitly kept out of.

**Quarantine** (verb):
To move a store the app cannot open aside, leaving the app free to start a new
empty one. Never destroys the store.

**Restore**:
To bring the matches from a Quarantined Store back into the live Match History,
keeping any matches played since the quarantine. A match already present is
never duplicated and never overwritten. Restoring never deletes the
Quarantined Store — only Discard or the automatic cap do that.
_Avoid_: recover, import, merge (as a user-facing word)

**Discard**:
To permanently delete a Quarantined Store at the player's explicit request.
The only user-facing delete in store recovery; everything else that removes a
Quarantined Store is the automatic newest-three cap.
_Avoid_: delete, remove, clear
