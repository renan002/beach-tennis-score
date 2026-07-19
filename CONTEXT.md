# Beach Tennis Counter

Matches are scored live on the watch, point by point, and completed matches are
kept on the phone. This glossary fixes the language for that split — in
particular for the three different things this project has historically called
"history".

## Language

### Matches

**Match**:
A single contest between two teams, from first point to final point. The unit a
player starts, scores, and finishes.

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
The unit of scoring won by taking points (0 → 15 → 30 → 40). Internally always
called a game, in both sports (`GameRecord`, Game Log).

**Set**:
In tennis, a real set — a collection of games. In beach tennis there are no
sets; the match is a single sequence of games, but the UI displays each beach
game as a "Set". This is the established Brazilian beach-tennis convention and
applies in every language, not just pt-BR.

> Display rule: the Game/Set label is a function of the sport, never of the
> locale. Beach tennis game-level labels read "Set N" in all languages; tennis
> reads "Game N" for games and "Set N" for sets in all languages ("game" and
> "set" are loanwords in pt-BR tennis).

### Monetization

**Pro**:
The one-time lifetime unlock, purchased on the iPhone. Pro gates Estatísticas,
Vários, and removes the watermark from the Cartão de Resultado. Scoring is
never gated: both sports are playable for free, and the watch app shows no
purchase UI and no paywall — every Pro touchpoint lives on the phone.
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
