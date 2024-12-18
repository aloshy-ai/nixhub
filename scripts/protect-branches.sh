#!/usr/bin/env bash

# ===== CONFIGURATION =====
PARALLEL_JOBS=5
DRY_RUN=false

# ===== FUNCTIONS =====
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local msg="$2"
    
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\r\033[K[%c] %s" "$spinstr" "$msg"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r\033[K"
}

check_auth() {
    echo "🔍 Checking GitHub authentication..."
    gh auth status > auth_status.tmp 2>&1
    
    if ! grep -q "Logged in to github.com" auth_status.tmp; then
        echo "❌ Not logged in to GitHub. Logging in..."
        rm auth_status.tmp
        gh auth login || exit 1
    fi

    if ! grep -q "Token scopes:.*repo" auth_status.tmp; then
        echo "❌ Missing required 'repo' scope. Re-authenticating..."
        rm auth_status.tmp
        gh auth login --scopes 'repo' || exit 1
    fi

    rm auth_status.tmp
}

protect_branch() {
    local repo="$1"
    local branch="$2"

    # Check dry run
    [ "$DRY_RUN" = "true" ] && {
        echo "[DRY RUN] Would protect $branch in $repo"
        return 0
    }

    # Check if branch exists
    gh api "/repos/$repo/branches/$branch" &>/dev/null || {
        echo "⏩ Skipping $repo ($branch not found)"
        return 0
    }

    # Protect branch
    gh api --method PUT "/repos/$repo/branches/$branch/protection" \
        -H "Accept: application/vnd.github+json" \
        --silent \
        --input - > protection_result.tmp 2>&1 <<EOF &
{
  "required_status_checks": {
    "strict": true,
    "contexts": []
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_linear_history": true,
  "required_conversation_resolution": true
}
EOF

    local pid=$!
    spinner $pid "Protecting $repo ($branch)"
    wait $pid
    local status=$?

    if [ $status -eq 0 ]; then
        echo "✅ Protected $repo ($branch)"
        rm -f protection_result.tmp
        return 0
    else
        echo "❌ Failed to protect $repo ($branch)"
        rm -f protection_result.tmp
        return 1
    fi
}

export -f protect_branch
export -f spinner
export DRY_RUN

# ===== MAIN SCRIPT =====
echo "🚀 Starting branch protection..."
check_auth

echo "📜 Processing repositories..."
gh repo list --json nameWithOwner,isPrivate --jq '.[] | select(.isPrivate==false) | .nameWithOwner' 2>/dev/null | \
parallel --will-cite -j "$PARALLEL_JOBS" \
    'if gh api "/repos/{}/branches/main" &>/dev/null; then
        protect_branch {} "main"
    else
        protect_branch {} "master"
    fi'

echo "✨ Done!"