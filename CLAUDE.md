# Buzz

> To have feedback, one first needs a feed.

Activity digests for Cloud Atlas AI. Shell script that composes gh + claude + curl.

## What This Does

```
GitHub PRs → LLM summarization → OH decision logs
   (noise)      (structure)        (context)
```

Extracts **direction** from merged PRs, not changelog entries. Part of the Matrix capture layer.

**Default mode:** Runs all repos, posts per-repo digests, generates executive summary for Activity Awareness aim.

## Files

| File | Purpose |
|------|---------|
| `buzz.sh` | Main script - fetch, summarize, post |
| `prompt.md` | LLM prompt for per-repo direction extraction |
| `repos.json` | Repo → OH endeavor ID mapping (+ `_activity_awareness_aim`) |
| `.last_run.json` | Auto-generated: tracks last successful run per repo |

## Usage

```bash
# All repos + executive summary (default)
./buzz.sh

# Single repo only
./buzz.sh miranda

# Preview without posting
./buzz.sh --dry-run

# Force re-post (ignores duplicate check)
./buzz.sh --force
```

## Last Run Tracking

Buzz tracks last successful run per repo in `.last_run.json`:
- First run: uses 24h ago as window
- Subsequent runs: uses last run timestamp
- No gaps, no duplicates

This file is auto-managed. Delete it to reset all windows to 24h.

## Environment

```bash
OH_API_URL=https://app.openhorizons.me
OH_API_KEY=your-key
```

## Development

This is intentionally simple. If you need to modify:

1. **buzz.sh** - The pipeline. Fetch → summarize → post.
2. **prompt.md** - Per-repo digest prompt. Direction over details.
3. **repos.json** - The mapping. Add new repos here.

### Adding a New Repo

1. Create endeavor in OH under Activity Awareness aim
2. Add entry to `repos.json`: `"repo-name": "endeavor-uuid"`
3. Test with `./buzz.sh repo-name --dry-run`

### Modifying the Prompt

The prompt in `prompt.md` shapes digest quality. Key principles:
- Direction over details
- Why it matters, not just what changed
- Handle edge cases (sparse PRs, incoherent batches)

Test prompt changes with `--dry-run` on repos with varied PR patterns.

## Examples

### Good Digest (Direction)
> **Direction:** Improving operational reliability for remote orchestration. Multiple PRs addressed command scoping and session lifecycle, preparing for multi-project workflows.
>
> **Highlights:** Added self-update capability. Fixed path traversal vulnerability.

### Bad Digest (Noise)
> Fixed 3 bugs. Added 2 features. Updated docs. Merged 5 PRs.

The good digest tells you *where the project is heading*. The bad digest just counts things.

## Troubleshooting

| Problem | Likely Cause | Fix |
|---------|--------------|-----|
| Script hangs | Auth issue | Check `gh auth status` and `claude --version` |
| "No endeavor ID found" | Repo not in repos.json | Add mapping to repos.json |
| Empty digest | No PRs merged since date | Delete `.last_run.json` or wait for activity |
| OH post fails | Bad API key or URL | Verify with `curl $OH_API_URL/api/contexts -H "Authorization: Bearer $OH_API_KEY"` |
| "Digest exists, skipping" | Already posted today | Use `--force` to override |

## OH Structure

```
Cloud Atlas AI (Context)
└── Build AI-Augmented Strategic OS (Mission)
    └── Activity Awareness (Aim) ← executive summary here
        ├── open-horizons (Initiative) ← per-repo digests
        ├── superego (Initiative)
        ├── miranda (Initiative)
        └── ... (repos)
```

## Dependencies

- `gh` CLI (authenticated with GitHub)
- `claude` CLI (authenticated with Anthropic)
- `jq` (JSON processing)
- `curl` (HTTP requests)

## Part of the Matrix

Buzz is a capture + structure tool for the [Matrix vision](../docs/the-matrix.md):

- **Capture**: Pull activity from GitHub
- **Structure**: LLM extracts themes and direction
- **Unified context**: Posts to OH, not scattered in GitHub

The bottleneck is context. Buzz helps fill it.
