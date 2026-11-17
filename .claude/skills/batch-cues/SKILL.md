---
name: batch-cues
description: Run one cues.live sandbox batch end to end - merge Blake's main, turn Josh's "Next batch" notes into changes, build and test, ship a numbered build to Dropbox, log it and push. Use when Josh types /batch-cues, optionally with a build number (/batch-cues 26), or asks to start the next sandbox batch or build.
---

# One sandbox batch

Turns Josh's notes into one numbered build he can test from Dropbox. One batch per session.
`AGENTS.md` (the project rules) applies to every change; `SANDBOX_TODO.md` ("How to work here")
is the workflow this skill follows.

Keep a task list with these steps, and tell Josh in a line when each one starts.

## 1. Start clean

- Work in this folder on the Mac mini, on `sandbox`. Stop and tell Josh if the branch is
  different, the working tree has uncommitted changes you did not make, or a worktree or side
  branch is left over from earlier work.
- `git pull --ff-only origin sandbox` so work pushed from elsewhere is here.
- The build number is the argument, or one more than the newest entry in
  `~/Library/CloudStorage/Dropbox/Sandbox/Cues App/Build notes.txt`.

## 2. Merge Blake's main

- `git fetch upstream`, then `git log sandbox..upstream/main`. If there is nothing new, say so
  and go on.
- Otherwise `git merge upstream/main`. Blake's code takes priority: keep his version and fit the
  sandbox change to it, or drop the sandbox change and note it for Josh.
- Conflicts that git resolves can still break the build, so build Mac and iOS and run the tests
  before committing the merge. The commit message lists each conflict and how it was resolved.
- Never rebase `sandbox` or force-push it.

## 3. Turn the notes into a batch

- Read "Next batch" and "Open (needs Josh)" in `SANDBOX_TODO.md`, and anything Josh pasted into
  the chat.
- Sort each note into one of:
  - **Do now:** UI, editing, or a contained fix. Check it against Blake's main first.
  - **Ask Josh:** unclear what he wants, or more than one reasonable reading.
  - **For Blake:** audio engine or render thread work, data format changes, or large features.
    Add these to "Not in scope here" with one line on why.
- Show Josh the sorted list and ask about the unclear ones in one question, before writing code.
  Skip the question when nothing is unclear.

## 4. Make the changes

- Follow `AGENTS.md`. In particular: register new files with `Scripts/pbxproj-sources.py`, use
  the design tokens, and add a test for new behaviour in `Services/` or `Models/` (a regression
  test first for a bug fix).
- When something can't be found or fixed, don't guess. Record what was checked and what Josh
  needs to provide (steps, a recording) under "Open (needs Josh)".
- Commit the batch: `Batch <n>: <short list>`, with one line per change in the body.

## 5. Build and ship

- Run `Scripts/make-sandbox-build.sh <number> "<label>" "<change>" ...` in the background (it
  takes several minutes). The label is two to five words. The changes are in Josh's words, one
  per line, saying what he will notice, not how it was done. The script checks the Mac and iOS
  builds, the tests and zero warnings, then copies the app to Dropbox and adds the build notes
  entry.
- If it stops on a failure, fix it, commit, and run it again. A failing engine timing test named
  in `AGENTS.md` is re-run on its own before treating it as real.

## 6. Log and push

- `SANDBOX_CHANGES.md`: add a `## Build <n> – <label> (<date>)` entry at the top, for Blake: what
  changed and why, how it works, the main files, the tests, and anything he should know before
  taking it.
- `SANDBOX_TODO.md`: remove what shipped, clear "Next batch", update "The last build was …", and
  list what Josh should retest under "Open (needs Josh)".
- Commit, then `git push origin sandbox`. Push nothing else; ask Josh before any other change on
  GitHub.

## 7. Report

Tell Josh the build's name in Dropbox, what changed in his words, what to retest, and what was
asked about, deferred to Blake, or left open.
