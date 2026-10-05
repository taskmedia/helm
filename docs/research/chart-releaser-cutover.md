# chart-releaser-action cutover research

> **Note on location:** no existing research/notes convention was found anywhere in this
> repository — no `docs/`, `docs/research/`, `notes/`, `RESEARCH.md`, or `CONTRIBUTING.md`
> on either the `main` or `gh-pages` branch. (The only existing docs are a bare README on
> `gh-pages`, not present on `main`, and the per-chart `templates/NOTES.txt` files that ship
> inside individual Helm charts — Helm's own post-install notes convention, unrelated to
> research notes.) Absent any convention to follow, this file was placed at
> `docs/research/chart-releaser-cutover.md` as a reasonable default location.

All claims below are sourced from primary material: the `helm/chart-releaser` Go source
(pinned to commit `ca9f474b97ffc16a8f78cc1c64cc41513510ee92` on `main` at research time),
the `helm/chart-releaser-action` repo, GitHub's own Actions documentation, and live `gh api`
calls against `taskmedia/helm` itself.

---

## Summary / Recommendation

1. **Q1 — cutover safety:** A first `chart-releaser` run against taskmedia/helm's existing
   `gh-pages` (legacy `.tgz` + `index.yaml`, no matching GitHub Releases) will **not corrupt
   or regenerate `index.yaml`** — `UpdateIndexFile` only *merges* into the existing file and
   only looks at the chart packages it was just asked to package/release, never at "all
   releases" or "all entries." But `skip_existing` dedupes purely against the GitHub Releases
   API (`GetRelease` by computed tag name), not against `index.yaml` content. Since no
   Releases exist yet for the already-published versions, chart-releaser will treat every
   currently-versioned chart as new and attempt to **create a brand-new GitHub Release for
   versions that are already live in `index.yaml`** — this succeeds (no tag collision) and
   produces a redundant, index-unreferenced Release rather than an error. Recommended fix:
   **option (a), bump every chart's version before the first chart-releaser run**, so
   chart-releaser only ever sees genuinely new versions and never touches the legacy
   history at all. Option (b) (pre-creating matching Releases for every historical version)
   also works but is far more work for the same outcome.

2. **Q2 — token permissions:** Per GitHub's own docs, the job/workflow-level `permissions:`
   block **can only narrow**, never widen, the repository's default `GITHUB_TOKEN`
   permissions. taskmedia/helm's repo-level setting
   (`default_workflow_permissions: "write"`, confirmed live below) already grants
   read/write by default, so a job declaring `permissions: contents: write` works today. If
   the repo default were ever `read`, no job-level `permissions:` block could override that
   repository/org ceiling — the "Workflow permissions" radio in Settings → Actions → General
   is the hard upper bound.

3. **Q3 — fork currency:** `helm/chart-releaser#587` is **still open, unmerged**, as of this
   research (last activity late September 2026, rebased, no merge commit). No stock release
   of `chart-releaser` (latest `v1.8.1`) or `chart-releaser-action` (latest `v1.7.0`, which
   itself defaults to pinning `chart-releaser` `v1.7.0`, not even the latest `v1.8.1`)
   contains the fix. **taskmedia/helm must keep using the `fty4` fork** (or carry an
   equivalent patch) until #587 merges and ships in a tagged `chart-releaser` release that a
   `chart-releaser-action` release then adopts as its default pinned version — switching to
   stock `helm/chart-releaser-action` today would reintroduce the immutable-releases bug
   #587 fixes.

**Bottom line for the cutover plan:** bump chart versions before flipping the switch (Q1),
no repo-settings change is needed for the token to work since `default_workflow_permissions`
is already `write` (Q2), and keep tracking `fty4/helm_chart-releaser-action@v1.8.1-rc1` — do
not attempt to move to the upstream action yet (Q3).

---

## Q1 — What happens on the first chart-releaser run against pre-existing, non-chart-releaser-managed `gh-pages` content?

**Direct answer:** `skip_existing` dedupes against **GitHub Releases visible via the GitHub
API only** — it does **not** consult `index.yaml` at all. `index.yaml` updates are a
**merge** into the existing file, not a regeneration from "all releases found." Concretely,
for taskmedia/helm's situation (packaged `.tgz` + `index.yaml` on `gh-pages`, zero matching
GitHub Releases):

- Every currently-versioned chart will look "new" to chart-releaser's `skip_existing` check,
  because that check only asks "does a GitHub Release with this tag name exist?" — and none
  do.
- chart-releaser will therefore attempt `CreateRelease` for every currently-versioned chart,
  **and it will succeed** (there's no existing tag/release to collide with), producing a
  real new GitHub Release carrying the packaged `.tgz`, even though that exact version is
  already live via the legacy mechanism.
- The subsequent index-update step will **not** duplicate or corrupt the `index.yaml` entry
  for that version: it loads the existing `index.yaml` from the `gh-pages` worktree,
  and for each chart it just released it only adds an entry if
  `indexFile.Get(packageName, packageVersion)` **doesn't already find one**. Since the
  legacy mechanism already wrote that exact name+version into `index.yaml`, the lookup
  succeeds and chart-releaser **skips adding anything** for it — the legacy entry is left
  completely untouched.
- Net effect: no crash, no data loss, no conflicting `index.yaml` entries — but a **redundant,
  functionally orphaned GitHub Release** gets created for every chart version that was
  already published by the legacy mechanism (its asset is uploaded but nothing in
  `index.yaml` ever points at it).

### Is this a merge or a full regeneration of `index.yaml`?

**Merge**, not regeneration from GitHub Releases. `UpdateIndexFile` explicitly loads the
file that already exists at `PagesIndexPath` on the `gh-pages` worktree and keeps it as the
base:

```go
var indexFile *repo.IndexFile
_, err = os.Stat(indexYamlPath)
if err == nil { // nolint: gocritic
    indexFile, err = repo.LoadIndexFile(indexYamlPath)
    if err != nil {
        return false, err
    }
} else if errors.Is(err, os.ErrNotExist) {
    indexFile = repo.NewIndexFile()
}
```

It then only iterates the **local package glob** (`PackagePath + "/*.tgz"` — i.e. only the
charts that were just packaged/released in this run, not "every release that has ever
existed in the repo"), fetches that chart's own GitHub Release via `GetRelease`, and for
each asset only adds it if it's missing from the already-loaded index:

```go
if _, err := indexFile.Get(packageName, packageVersion); err != nil {
    if err := r.addToIndexFile(indexFile, downloadURL.String()); err != nil {
        return false, err
    }
    update = true
    break
}
```

So the risk of legacy entries being **dropped** on first run does not apply here — they are
never visited at all unless the corresponding chart is re-packaged in the same run, and even
then they are preserved rather than overwritten, because the base index is loaded from disk
first.
Source: `helm/chart-releaser` `pkg/releaser/releaser.go`, `UpdateIndexFile`, lines 91–227 —
https://github.com/helm/chart-releaser/blob/ca9f474b97ffc16a8f78cc1c64cc41513510ee92/pkg/releaser/releaser.go#L91-L227
(index-merge load at
https://github.com/helm/chart-releaser/blob/ca9f474b97ffc16a8f78cc1c64cc41513510ee92/pkg/releaser/releaser.go#L124-L135,
existing-entry check at
https://github.com/helm/chart-releaser/blob/ca9f474b97ffc16a8f78cc1c64cc41513510ee92/pkg/releaser/releaser.go#L178-L184).

### How `skip_existing` actually decides "already released"

`CreateReleases()` is the step that uploads/creates GitHub Releases. Its `skip_existing`
check is purely an API lookup by the computed release/tag name, with the lookup error
discarded (so a 404 is indistinguishable from "didn't check" — either way it proceeds to
create):

```go
if r.config.SkipExisting {
    existingRelease, _ := r.github.GetRelease(context.TODO(), releaseName)
    if existingRelease != nil {
        continue
    }
}
```

Source:
https://github.com/helm/chart-releaser/blob/ca9f474b97ffc16a8f78cc1c64cc41513510ee92/pkg/releaser/releaser.go#L402-L407

`GetRelease` itself is a thin wrapper over `go-github`'s `GetReleaseByTag`, which returns a
non-nil `error` (and nil release) on a 404 — confirming the lookup is genuinely
Release-API-based, not `index.yaml`-based, and that a missing release is treated as
"not found" rather than panicking:

```go
func (c *Client) GetRelease(_ context.Context, tag string) (*Release, error) {
    release, _, err := c.Repositories.GetReleaseByTag(context.TODO(), c.owner, c.repo, tag)
    if err != nil {
        return nil, err
    }
    ...
}
```

Source:
https://github.com/helm/chart-releaser/blob/ca9f474b97ffc16a8f78cc1c64cc41513510ee92/pkg/github/github.go#L88-L103

### Which of (a)/(b)/(c) does taskmedia/helm need?

- **(a) bump every chart's version before the first run — recommended.** Since
  `CreateReleases`/`UpdateIndexFile` only ever look at the chart packages produced for *this*
  run (via `cr package`, which packages whatever `Chart.yaml` currently declares), bumping
  every chart to a new version before the first chart-releaser run guarantees chart-releaser
  never even considers the legacy, already-published versions — there is nothing to
  dedupe, nothing to collide with, and no redundant Releases get created. This is the
  simplest, lowest-risk option and requires no backfill work.
- **(b) pre-create matching GitHub Releases for every version in the current `index.yaml` —
  works, but is unnecessary extra effort.** It would make `skip_existing` correctly treat
  all historical versions as "already released" and skip them, but requires manually
  recreating a Release (with matching tag name per `ReleaseNameTemplate`, default
  `"{{ .Name }}-{{ .Version }}"`) for every chart/version combination currently live on
  `gh-pages` — one API call and the right tag format per legacy version.
- **(c) "neither, because of a specific mechanism" does not apply.** There is no mechanism in
  chart-releaser that reconciles `index.yaml` content against release history; the two are
  only loosely connected by the asset-presence check described above. Doing nothing at all is
  *not* catastrophic (no corruption, no crash) but *does* leave a trail of redundant,
  unreferenced GitHub Releases for every already-published version — annoying, not harmful.

---

## Q2 — Does `CR_TOKEN: secrets.GITHUB_TOKEN` need a change to the repo's "Workflow permissions" setting?

**Direct answer:** No change to the repo-level setting is required for taskmedia/helm,
because its current repo-level default is already `"write"` (confirmed live below) — a job
declaring `permissions: contents: write` works today without touching Settings → Actions →
General. More generally, per GitHub's own documentation, the job/workflow `permissions:`
block can only act as a **ceiling-respecting override that narrows** the repository's
default; it can never grant a scope broader than what the repository (or enterprise/org)
default allows:

> "You can disable or limit the `GITHUB_TOKEN` permissions for an individual job... You can
> use the `permissions` key in your workflow file to modify permissions for the
> `GITHUB_TOKEN`... Workflows set the default permissions, which can then be adjusted at the
> job or workflow level."
>
> "Each job... creates a new `GITHUB_TOKEN` secret... You can set the permissions... When
> you specify the permissions for the `GITHUB_TOKEN` in a workflow, you set a default
> permission for all jobs in the workflow, or per job for specific jobs."

Source (GitHub Docs, "Automatic token authentication" /
"Controlling permissions for `GITHUB_TOKEN`"):
https://docs.github.com/en/actions/security-guides/automatic-token-authentication
and https://docs.github.com/en/actions/using-jobs/assigning-permissions-to-jobs

The repository-level "Workflow permissions" toggle (Settings → Actions → General →
"Read and write permissions" vs "Read repository contents and packages permissions")
sets the **default** the `permissions:` block starts from and narrows; if the repo default
is `read`, a job can still request `contents: write` in its `permissions:` block (this is
how most "least privilege" workflows work — job-level narrows the default downward), but it
cannot escalate beyond a *hard* restriction imposed at the organization/enterprise level
(e.g. an org-wide policy pinning workflow permissions to read-only, which does override
anything a workflow file requests). For a single, non-org-restricted repository, the
job-level `permissions:` block is what actually governs the token's effective scope at
run time, as long as it does not exceed an enterprise/org-enforced ceiling.

### Live check against taskmedia/helm

```
$ GH_HOST=github.com gh api repos/taskmedia/helm --jq '.default_branch, .permissions'
gh-pages
{"admin":true,"maintain":true,"pull":true,"push":true,"triage":true}
```

```
$ GH_HOST=github.com gh api repos/taskmedia/helm/actions/permissions/workflow --jq .
{"can_approve_pull_request_reviews":true,"default_workflow_permissions":"write"}
```

Both calls succeeded (no auth/permission errors). `default_workflow_permissions` is
`"write"`, i.e. the repo's "Workflow permissions" setting is already on
**"Read and write permissions"**. A job that declares `permissions: contents: write` will
therefore get a `GITHUB_TOKEN` that can push commits to `gh-pages` and create Releases
without any further settings change. (Note: `default_branch` is currently `gh-pages`, not
`main` — worth flagging separately since it's unrelated to token scope but relevant to the
overall cutover context.)

---

## Q3 — Is `fty4/helm_chart-releaser-action` still needed, or does a stock release already include the fix from PR #587?

**Direct answer:** `helm/chart-releaser#587` ("fix: support repositories with immutable
releases enabled") is **still open and unmerged**. No current stock release of either
`chart-releaser` or `chart-releaser-action` contains it, so taskmedia/helm cannot switch to
the upstream action yet — the `fty4` fork (or an equivalent local patch) remains necessary.

### PR #587 status (live API check)

```
$ GH_HOST=github.com gh api repos/helm/chart-releaser/pulls/587 \
    --jq '{state, merged, merged_at, merge_commit_sha, base: .base.ref, html_url, title}'
{
  "state": "open",
  "merged": false,
  "merged_at": null,
  "merge_commit_sha": "87fe0ac8838d1fe0e8bddb1f0fe13e643adb3d0d",
  "base": "main",
  "html_url": "https://github.com/helm/chart-releaser/pull/587",
  "title": "fix: support repositories with immutable releases enabled"
}
```

`merged: false` / `merged_at: null` confirm it is unmerged (the `merge_commit_sha` field
GitHub populates speculatively for open, mergeable PRs — it is not evidence of an actual
merge). PR: https://github.com/helm/chart-releaser/pull/587. The PR addresses GitHub's
immutable-releases feature by making `chart-releaser` create the GitHub Release as a draft,
upload assets to the draft, then publish it — because immutable releases (GA since
October 2025) reject the previous create-then-upload sequence outright. It targets
`helm/chart-releaser-action#228`.

### Current stock releases — neither contains the fix

```
$ GH_HOST=github.com gh api repos/helm/chart-releaser/releases --jq '.[0:5][] | {tag: .tag_name, published: .published_at}'
{"tag":"v1.8.1","published":"2025-06-02T14:01:13Z"}
{"tag":"v1.8.0","published":"2025-06-02T13:00:43Z"}
{"tag":"v1.7.0","published":"2024-12-18T09:41:12Z"}
{"tag":"v1.6.1","published":"2023-10-31T07:44:58Z"}
{"tag":"v1.6.0","published":"2023-06-27T09:53:59Z"}
```

```
$ GH_HOST=github.com gh api repos/helm/chart-releaser-action/releases --jq '.[0:5][] | {tag: .tag_name, published: .published_at}'
{"tag":"v1.7.0","published":"2025-01-20T10:56:38Z"}
{"tag":"v1.6.0","published":"2023-11-02T16:48:57Z"}
{"tag":"v1.5.0","published":"2023-01-06T15:36:45Z"}
{"tag":"v1.4.1","published":"2022-09-28T12:49:23Z"}
{"tag":"v1.4.0","published":"2022-03-30T08:26:56Z"}
```

Latest `chart-releaser` is `v1.8.1` (June 2025) — predates PR #587's activity and cannot
contain an unmerged PR's changes. Latest `chart-releaser-action` is `v1.7.0` (January 2025).

### Which `chart-releaser` version does `chart-releaser-action` actually pin?

`chart-releaser-action`'s `main`-branch `action.yml` and its install script `cr.sh` both
default to pinning `chart-releaser` **`v1.7.0`** — not even the newer `v1.8.1`:

```yaml
inputs:
  version:
    description: "The chart-releaser version to use (default: v1.7.0)"
    required: false
    default: v1.7.0
```
Source: https://github.com/helm/chart-releaser-action/blob/main/action.yml (sha `214b25bcf2cfebbd63780d2d94aee39e179ef575` at research time)

```bash
DEFAULT_CHART_RELEASER_VERSION=v1.7.0
```
Source: https://github.com/helm/chart-releaser-action/blob/main/cr.sh

So even if PR #587 merged into `chart-releaser` tomorrow and shipped as, say, `v1.9.0`,
the stock `chart-releaser-action` would still download `v1.7.0` by default until its own
`DEFAULT_CHART_RELEASER_VERSION`/`version` input default is bumped in a subsequent
`chart-releaser-action` release — two separate release events are required upstream
(a `chart-releaser` release containing the fix, and a `chart-releaser-action` release
updating its pinned default to that version, or an explicit `version:` override in the
calling workflow) before taskmedia/helm could drop the fork and consume the stock action
pinned to a fixed `chart-releaser` version directly.

**Conclusion:** keep tracking `fty4/helm_chart-releaser-action@v1.8.1-rc1` (or whatever
later fork tag), and re-check `helm/chart-releaser#587`'s merge status plus the two release
histories above periodically — there is nothing to switch to yet.
