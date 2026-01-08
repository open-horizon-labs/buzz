# Buzz

> To have feedback, one first needs a feed.

LLM-powered activity digests for the Cloud Atlas AI ecosystem. Captures what's happening, extracts direction, surfaces to OH.

## What It Does

```
GitHub PRs → LLM summarization → OH decision logs
   (noise)      (structure)        (context)
```

20 PR titles become: "Miranda: hardening operational commands, better session management."

## Usage

```bash
# Digest merged PRs from a repo, post to OH
./buzz.sh cloud-atlas-ai/open-horizons

# Custom date range
./buzz.sh cloud-atlas-ai/miranda --since 2026-01-01

# Dry run (preview without posting)
./buzz.sh cloud-atlas-ai/superego --dry-run
```

## Requirements

- `gh` CLI (authenticated)
- `claude` CLI (authenticated)
- `OH_API_KEY` and `OH_API_URL` environment variables

## Architecture

Shell script. ~30 lines. Composes existing tools.

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
    └── Activity Awareness (Aim)
        ├── open-horizons (Initiative) ← digests here
        ├── superego (Initiative)
        └── ...
```

Digests become decision logs on the repo's endeavor.

## Part of The Matrix

Buzz is a capture + structure tool for the [Matrix vision](../docs/the-matrix.md):

- **Capture**: Pull activity from GitHub
- **Structure**: LLM extracts themes and direction
- **Unified context**: Posts to OH, not scattered in GitHub

The bottleneck is context. Buzz helps fill it.
