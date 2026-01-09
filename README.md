# Buzz

> To have feedback, one first needs a feed.

LLM-powered activity digests for the Cloud Atlas AI ecosystem. Captures what's happening, extracts direction, surfaces to OH.

## What It Does

```
GitHub PRs → LLM summarization → OH decision logs
   (noise)      (structure)        (context)
```

20 PR titles become: "The ecosystem is solidifying from 'collection of tools' into 'coherent platform'."

## Usage

```bash
# All repos + executive summary (default)
./buzz.sh

# Single repo
./buzz.sh miranda

# Preview without posting
./buzz.sh --dry-run

# Force re-post (override duplicate detection)
./buzz.sh --force
```

## Requirements

- `gh` CLI (authenticated)
- `claude` CLI (authenticated)
- `OH_API_KEY` environment variable

## Architecture

Shell script composing existing tools:

```
buzz.sh
├── gh pr list          # fetch merged PRs
├── claude              # summarize into direction
└── curl                # post to OH API
```

## OH Integration

Each repo maps to an endeavor in the Cloud Atlas AI context:

```
Cloud Atlas AI (Context)
└── Build AI-Augmented Strategic OS (Mission)
    └── Activity Awareness (Aim) ← executive summary
        ├── open-horizons (Initiative) ← per-repo digests
        ├── superego (Initiative)
        └── ...
```

## Part of The Matrix

Buzz is a capture + structure tool for the [Matrix vision](../docs/the-matrix.md):

- **Capture**: Pull activity from GitHub
- **Structure**: LLM extracts themes and direction
- **Unified context**: Posts to OH, not scattered in GitHub

The bottleneck is context. Buzz helps fill it.
