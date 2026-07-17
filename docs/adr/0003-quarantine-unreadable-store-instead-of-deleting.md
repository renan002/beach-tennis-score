# Quarantine an unreadable store instead of deleting it; restore by merging on match id

When the app cannot open its store, it moves the files into a timestamped
`quarantined-store-<date>/` folder and starts a new empty one, rather than
deleting them as it did through v1.2.1. The phone's store is the **only**
durable record of Match History — the watch keeps just a single pending
transfer, never past matches — so a failed open used to destroy a player's
entire history with no way back. The app still always launches; the old data
merely stops being destroyed on the way there.

Nothing reads a Quarantined Store today. That is intended: quarantining is
write-side only, and buys the option of a restore flow that does not exist yet.
A folder full of databases nobody reads looks like dead code without this note.

## Considered Options

- **Delete the store (the v1.2.1 behaviour)** — rejected. The likeliest trigger
  is a schema change shipped without a migration path, so the first launch after
  an update would silently and irreversibly wipe every match the player had.
- **Restore by replacing the live store with the quarantined one** — rejected.
  A player keeps playing after a quarantine, so replacing destroys every match
  recorded since; to make it safe you must first quarantine the live store,
  which is the same problem one level up. **Restore merges on match id instead**,
  inserting only matches whose id is not already live. Match id is already the
  identity rule for watch-to-phone transfers (`PhoneSessionManager`, dedup on
  `$0.id == matchId`), so merge reuses an established rule rather than inventing
  one, and is idempotent — a half-finished restore can simply be re-run.
- **Never delete under any circumstance** — rejected, narrowly. If a file cannot
  be moved aside at all, the app deletes it rather than refusing to launch. This
  is the single sanctioned delete in the recovery path. Both files sit in one
  directory on one volume, so the move is a rename; the realistic triggers left
  are a permissions failure or a busy file. Two paths that reached this delete
  unintentionally are closed: a same-second retry now picks a distinct folder
  (`-2`, `-3`) instead of colliding, and a backup directory that cannot be
  created aborts the whole operation rather than letting every failed move fall
  through to the delete.
- **Adding versioned schemas and a real migration plan** — deferred, not
  rejected. It treats the disease rather than the symptom, but is far larger
  than the fix it would replace, and quarantining is still wanted as a backstop
  for the failures a migration plan does not cover.

## Consequences

- **Restore requires pointing a container at an explicit store URL** — the one
  thing plan 007 forbade as out of scope. That plan's constraint and this
  direction disagree, and the restore work must consciously lift it.
- **A quarantine's cause is only knowable at quarantine time.** A manifest
  recorded alongside the files (app version, build, timestamp, underlying error)
  is what a later build uses to tell a v1.2 store from a v1.3 one, and a schema
  failure from disk corruption. There are no versioned schemas to consult, so
  the app version that wrote the store is the only available proxy — and it is
  unrecoverable if not captured at the moment of failure.
- **Quarantined stores are capped at the newest three and excluded from iCloud
  backup**, bounding both disk use and the player's device backup. The cap
  auto-deletes old stores, which is in tension with the point of this decision;
  it is accepted because a crash loop that writes a partial store on each launch
  would otherwise accumulate folders without limit, and the newest quarantine is
  the one worth keeping.
