# Release a package (shared procedure)

Shared by the Corvina repos that publish with the workflows of this repo (`publish-npm.yaml`,
`publish-helm-chart.yaml`). Each repo has a small `.claude/skills/release-package/SKILL.md` stub with its
**package table** (tag prefix, folder, workflow) and points here for the procedure: read the table from the stub,
then follow these rules and steps.

## Rules

- A release is a **GitHub release together with its tag**, created at once (`gh release create` creates the tag).
  The publish workflows take the version from the tag and commit the version bump themselves: **never** edit
  `package.json` / `Chart.yaml` / `lerna.json` versions before releasing.
- Tags **never have a leading `v`** before the version: `1.2.0`, `my-lib-1.2.0` — not `v1.2.0` / `my-lib-v1.2.0`.
  Older tags may have it (the workflows accept both); new ones must not.
- The **main package** of a repo (the one at the root) is tagged with the bare version `X.Y.Z`, has GitHub's
  generated notes and is marked **Latest**.
- The **other packages** (in a subfolder) are tagged `<prefix>X.Y.Z`, are titled exactly as the tag, have notes
  **scoped to the changes of their subfolder** and are **not** Latest.
- **Prereleases** (`X.Y.Z-rc.N`, `-beta.N`, ...) are marked as prerelease and are never Latest. They may target a
  branch (e.g. a PR branch to try out). Stable releases always target the default branch.
- A release is public and triggers a publish: **ask the user to confirm** version, tag, target and notes before
  creating it.

## Steps

`$REPO` is the repo (`gh repo view --json nameWithOwner -q .nameWithOwner`), `$DEFAULT` its default branch
(`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`).

1. **Sync and pick the target** (`$TARGET`): `git fetch origin --tags`.
   - stable: `$DEFAULT`. Make sure the PRs meant to be in it are merged (`gh pr view <n> --json state`); never tag
     a branch.
   - prerelease: `$DEFAULT` or a pushed branch, whose last commit is on `origin/<branch>`.

2. **Find the previous release of the same package** (stable tags only, unless releasing from a prerelease line).
   Old tags may carry a `v`, so the version is normalized before sorting:
   ```bash
   prev_tag() {  # prev_tag <tag-prefix>, '' for the main package
     git tag -l "$1*" | awk -v p="$1" 'index($0, p) == 1 {
       v = substr($0, length(p) + 1); sub(/^v/, "", v)
       if (v ~ /^[0-9]+\.[0-9]+\.[0-9]+$/) print v, $0 }' | sort -V | tail -1 | cut -d' ' -f2
   }
   ```
   No previous tag: it is the first release, use the full history.

3. **List the changes** since it: `git log --oneline <prev>..origin/$TARGET -- <folder>` (main package: whole
   repo). If there are none, stop and say so.

4. **Propose the version** (semver from the changes: breaking → major, feature → minor, fix → patch; prerelease
   `X.Y.Z-rc.N`) and ask for confirmation, showing tag, title, target, Latest or not, and the notes.

5. **Create the release with gh**.

   Main package:
   ```bash
   gh release create "$TAG" --target "$TARGET" --title "$TAG" --generate-notes --notes-start-tag "$PREV" --latest
   ```

   Package in a subfolder — notes from `scoped-notes.sh` (next to this file), which keeps the commits that touched
   the folder, drops the `[skip ci]` version-bump commits of the workflows and writes one line per PR:
   ```bash
   gh api "repos/Corvina-R-D/corvina-github-public-actions/contents/skills/release-package/scoped-notes.sh" \
     -H 'Accept: application/vnd.github.raw' > "$SCRATCH/scoped-notes.sh"
   bash "$SCRATCH/scoped-notes.sh" "$PREV" "origin/$TARGET" "$TAG" "$FOLDER" > "$SCRATCH/notes-$TAG.md"
   # show the notes to the user, then:
   gh release create "$TAG" --target "$TARGET" --title "$TAG" --notes-file "$SCRATCH/notes-$TAG.md" --latest=false
   ```
   (`$SCRATCH`: the session scratchpad, or a `mktemp -d`.)

   Prerelease (any package): add `--prerelease` and use `--latest=false`, also for the main package. Its notes may
   be a short summary of what is being tried out.

6. **Verify**: `gh release view "$TAG"` (title, tag, notes, Latest), then `gh run list --limit 5` to check that the
   publish workflow named in the stub started; report its URL. Workflows that bump the version on the default
   branch, or the version of a lib in a template, do it through a PR that may need approval: mention it.

## Without gh (or if it fails)

Guide the user through the web UI:

1. Open `https://github.com/$REPO/releases/new?tag=<TAG>&target=<TARGET>&title=<TAG>` (add `&prerelease=1` for
   a prerelease).
2. "Choose a tag" shows `<TAG>` as **Create new tag on publish**, on `<TARGET>`.
3. Release notes:
   - main package: "Generate release notes", previous tag `<PREV>`.
   - package in a subfolder: paste the scoped notes (from `scoped-notes.sh`, or the PRs of
     `git log <PREV>..origin/<TARGET> -- <folder>`). **Not** "Generate release notes": it lists every PR of the
     repo.
4. "Set as the latest release": checked **only** for a stable release of the main package.
5. "Publish release".
