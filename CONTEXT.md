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
never duplicated and never overwritten.
_Avoid_: recover, import, merge (as a user-facing word)
