#!/bin/bash
# buzz - activity digests for Cloud Atlas AI
# "To have feedback, one first needs a feed."

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Config
REPOS_FILE="$SCRIPT_DIR/repos.json"
LAST_RUN_FILE="$SCRIPT_DIR/.last_run.json"
PROMPT_FILE="$SCRIPT_DIR/prompt.md"
SUMMARY_PROMPT_FILE="$SCRIPT_DIR/summary_prompt.md"

# Defaults
OH_API_URL="https://app.openhorizons.me"
DRY_RUN=false

usage() {
    cat <<EOF
Usage: buzz [repo] [options]

Generate activity digests from merged PRs and post to OH.

Arguments:
    repo        Optional. Repository name (e.g., miranda, open-horizons)
                If omitted, runs all repos and generates executive summary.

Options:
    --dry-run       Preview digest without posting to OH
    -h, --help      Show this help

Environment:
    OH_API_KEY          Open Horizons API key (required unless --dry-run)
    ANTHROPIC_API_KEY   If set, uses Anthropic API directly instead of claude CLI

Examples:
    buzz                    # All repos + executive summary
    buzz miranda            # Single repo
    buzz --dry-run          # Preview all repos
EOF
    exit 0
}

# Parse arguments
REPO=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            REPO="$1"
            shift
            ;;
    esac
done

# Check environment
if [[ "$DRY_RUN" == false ]]; then
    if [[ -z "${OH_API_KEY:-}" ]]; then
        echo "Error: OH_API_KEY required (or use --dry-run)" >&2
        exit 1
    fi
fi

# Validate config files
if [[ ! -f "$REPOS_FILE" ]]; then
    echo "Error: repos.json not found at $REPOS_FILE" >&2
    exit 1
fi
if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "Error: prompt.md not found at $PROMPT_FILE" >&2
    exit 1
fi

TODAY=$(date +%Y-%m-%d)

# Call LLM with prompt and input
# Uses Anthropic API if ANTHROPIC_API_KEY is set, otherwise claude CLI
call_llm() {
    local prompt="$1"
    local input="$2"

    if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        # Use Anthropic API directly
        local escaped_prompt=$(echo "$prompt" | jq -Rs .)
        local escaped_input=$(echo "$input" | jq -Rs .)

        local response=$(curl -s "https://api.anthropic.com/v1/messages" \
            -H "x-api-key: $ANTHROPIC_API_KEY" \
            -H "anthropic-version: 2023-06-01" \
            -H "content-type: application/json" \
            -d "{
                \"model\": \"claude-opus-4-5\",
                \"max_tokens\": 1024,
                \"messages\": [{
                    \"role\": \"user\",
                    \"content\": ${escaped_prompt}
                }, {
                    \"role\": \"user\",
                    \"content\": ${escaped_input}
                }]
            }")

        echo "$response" | jq -r '.content[0].text // empty'
    else
        # Use claude CLI
        echo "$input" | claude -p "$prompt" --output-format text
    fi
}

# Get SINCE date for a repo (from last run or 24h ago)
get_since() {
    local repo="$1"
    if [[ -f "$LAST_RUN_FILE" ]]; then
        local last_run=$(jq -r --arg repo "$repo" '.[$repo] // empty' "$LAST_RUN_FILE")
        if [[ -n "$last_run" ]]; then
            echo "$last_run"
            return
        fi
    fi
    date -v-1d +%Y-%m-%dT%H:%M:%S
}

# Update last run time for a repo
update_last_run() {
    local repo="$1"
    local now=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    if [[ -f "$LAST_RUN_FILE" ]]; then
        jq --arg repo "$repo" --arg time "$now" '.[$repo] = $time' "$LAST_RUN_FILE" > "$LAST_RUN_FILE.tmp" \
            && mv "$LAST_RUN_FILE.tmp" "$LAST_RUN_FILE"
    else
        echo "{\"$repo\": \"$now\"}" > "$LAST_RUN_FILE"
    fi
}

# Post digest to OH
post_to_oh() {
    local endeavor_id="$1"
    local content="$2"
    local escaped=$(echo "$content" | jq -Rs .)

    curl -s -X POST "${OH_API_URL}/api/logs?relaxed=true" \
        -H "Authorization: Bearer $OH_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"entity_type\": \"endeavor\",
            \"entity_id\": \"$endeavor_id\",
            \"log_date\": \"$TODAY\",
            \"content\": $escaped
        }"
}

# Process a single repo, returns digest on stdout
process_repo() {
    local short_name="$1"
    local endeavor_id=$(jq -r --arg repo "$short_name" '.[$repo] // empty' "$REPOS_FILE")

    if [[ -z "$endeavor_id" ]]; then
        echo "Error: No endeavor ID for '$short_name'" >&2
        return 1
    fi

    local repo="open-horizon-labs/$short_name"
    local since=$(get_since "$short_name")

    echo "[$short_name] Fetching commits since $since..." >&2

    local commits=$(gh api "repos/$repo/commits?since=$since" \
        --jq '[.[] | {sha: .sha[0:7], message: .commit.message, author: .commit.author.name, date: .commit.committer.date}]')

    local commit_count=$(echo "$commits" | jq 'length')

    if [[ "$commit_count" == "0" ]]; then
        echo "[$short_name] No commits" >&2
        return 0
    fi

    echo "[$short_name] Found $commit_count commits, generating digest..." >&2

    local digest=$(call_llm "$(cat "$PROMPT_FILE")" "$commits") || {
        echo "[$short_name] LLM summarization failed" >&2
        return 1
    }

    if [[ -z "$digest" ]]; then
        echo "[$short_name] Empty digest" >&2
        return 0
    fi

    echo ""
    echo "## $short_name"
    echo ""
    echo "$digest"

    if [[ "$DRY_RUN" == false ]]; then
        local response=$(post_to_oh "$endeavor_id" "$digest")
        if echo "$response" | jq -e '.success' > /dev/null 2>&1; then
            echo "[$short_name] Posted to OH" >&2
            update_last_run "$short_name"
        else
            echo "[$short_name] Failed to post: $response" >&2
        fi
    fi
}

# Single repo mode
if [[ -n "$REPO" ]]; then
    # Normalize short name
    SHORT_NAME="${REPO#*/}"
    if [[ "$REPO" == */* ]]; then
        SHORT_NAME="${REPO#*/}"
    else
        SHORT_NAME="$REPO"
    fi

    process_repo "$SHORT_NAME"
    exit 0
fi

# All repos mode
echo "=== Buzz Activity Digest ($TODAY) ==="
echo ""

ALL_DIGESTS=""
REPOS_WITH_ACTIVITY=()

# Get all repos (exclude _-prefixed keys)
REPO_LIST=$(jq -r 'keys[] | select(startswith("_") | not)' "$REPOS_FILE")

for repo in $REPO_LIST; do
    digest=$(process_repo "$repo")
    if [[ -n "$digest" ]]; then
        ALL_DIGESTS+="$digest"
        ALL_DIGESTS+=$'\n'
        REPOS_WITH_ACTIVITY+=("$repo")
    fi
done

if [[ ${#REPOS_WITH_ACTIVITY[@]} -eq 0 ]]; then
    echo "No activity across any repos"
    exit 0
fi

echo ""
echo "=== Executive Summary ==="
echo ""

# Generate executive summary
if [[ ! -f "$SUMMARY_PROMPT_FILE" ]]; then
    # Inline summary prompt if file doesn't exist
    SUMMARY_PROMPT="Summarize the following activity digests from multiple repositories into a brief executive summary (2-3 sentences). Focus on the overall direction and key themes across the ecosystem. What's the big picture?"
else
    SUMMARY_PROMPT=$(cat "$SUMMARY_PROMPT_FILE")
fi

EXEC_SUMMARY=$(call_llm "$SUMMARY_PROMPT" "$ALL_DIGESTS") || {
    echo "Error: Executive summary generation failed" >&2
    exit 1
}

echo "$EXEC_SUMMARY"
echo ""

if [[ "$DRY_RUN" == true ]]; then
    echo "[Dry run - not posting executive summary to OH]"
    exit 0
fi

# Post executive summary to Activity Awareness aim
AIM_ID=$(jq -r '._activity_awareness_aim // empty' "$REPOS_FILE")
if [[ -z "$AIM_ID" ]]; then
    echo "Warning: No _activity_awareness_aim in repos.json, skipping executive summary post" >&2
    exit 0
fi

RESPONSE=$(post_to_oh "$AIM_ID" "$EXEC_SUMMARY")
if echo "$RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
    echo "Posted executive summary to Activity Awareness"
else
    echo "Error posting executive summary: $RESPONSE" >&2
    exit 1
fi
