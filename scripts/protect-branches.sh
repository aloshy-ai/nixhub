#!/usr/bin/env bash

# ===== CONFIGURATION =====
PARALLEL_JOBS=5
DRY_RUN=false

# ===== FUNCTIONS =====
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

    echo "✅ Authentication check passed."
    rm auth_status.tmp
}

protect_branch() {
    local repo="$1"
    local branch="$2"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "🧪 [DRY RUN] Would protect $branch in $repo"
        return 0
    fi

    if gh api "/repos/$repo/branches/$branch" &>/dev/null; then
        echo "🔒 Protecting $branch in $repo..."
        if gh api --method PUT "/repos/$repo/branches/$branch/protection" \
            -H "Accept: application/vnd.github+json" \
            --input - <<EOF
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
        then
            echo "✅ Protected $branch in $repo"
            return 0
        else
            echo "❌ Failed to protect $branch in $repo"
            return 1
        fi
    else
        echo "ℹ️ Branch $branch not found in $repo. Skipping..."
        return 0
    fi
}

export -f protect_branch
export DRY_RUN

# ===== MAIN SCRIPT =====
echo "🚀 Starting GitHub branch protection script..."
check_auth

echo "📜 Fetching and processing public repositories..."
gh repo list --json nameWithOwner,isPrivate --jq '.[] | select(.isPrivate==false) | .nameWithOwner' | \
parallel -j "$PARALLEL_JOBS" --bar \
    'for branch in main master; do protect_branch {} "$branch"; done'

echo "🎉 Script completed!"