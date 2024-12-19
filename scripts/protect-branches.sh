#!/usr/bin/env bash

# ===== CONFIGURATION =====
PARALLEL_JOBS=5
DRY_RUN=false
EXCLUDED_REPOS=""

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

is_excluded_repo() {
    local repo="$1"
    if [[ -n "$EXCLUDED_REPOS" && ",$EXCLUDED_REPOS," == *",$repo,"* ]]; then
        return 0
    fi
    return 1
}

is_admin() {
    local repo="$1"
    if gh api "/repos/$repo" --jq '.permissions.admin' 2>/dev/null | grep -q "true"; then
        return 0
    fi
    return 1
}

protect_branch() {
    local repo="$1"
    local branch="$2"

    # Check if repo is in exclusion list
    if is_excluded_repo "$repo"; then
        echo "⏩ Skipping $repo (in exclusion list)"
        return 0
    fi

    # Check if user is admin
    if is_admin "$repo"; then
        echo "⏩ Skipping $repo (admin repository)"
        return 0
    fi

    # Check dry run
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would protect $branch in $repo"
        return 0
    fi

    # Check if branch exists
    if ! gh api "/repos/$repo/branches/$branch" &>/dev/null; then
        echo "⏩ Skipping $repo ($branch not found)"
        return 0
    fi

    # Protect branch
    {
        gh api --method PUT "/repos/$repo/branches/$branch/protection" \
            -H "Accept: application/vnd.github+json" \
            --silent \
            --input - > protection_result.tmp 2>&1 <<EOF
{
  "required_status_checks": {
    "strict": true,
    "contexts": []
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "allow_force_pushes": true,
  "allow_deletions": false,
  "required_linear_history": true,
  "required_conversation_resolution": true
}
EOF
    } &

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
        cat protection_result.tmp
        rm -f protection_result.tmp
        return 1
    fi
}

# Define the worker script that will be used by parallel
read -r -d '' WORKER_SCRIPT << 'WRKEREOF'
protect_branch() {
    local repo="$1"
    local branch="$2"

    # Check if user is admin
    if gh api "/repos/$repo" --jq '.permissions.admin' 2>/dev/null | grep -q "true"; then
        echo "⏩ Skipping $repo (admin repository)"
        return 0
    fi

    # Check if branch exists
    if ! gh api "/repos/$repo/branches/$branch" &>/dev/null; then
        echo "⏩ Skipping $repo ($branch not found)"
        return 0
    fi

    # Protect branch
    if gh api --method PUT "/repos/$repo/branches/$branch/protection" \
        -H "Accept: application/vnd.github+json" \
        --input - <<INNEREOF
{
  "required_status_checks": {
    "strict": true,
    "contexts": []
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "allow_force_pushes": true,
  "allow_deletions": false,
  "required_linear_history": true,
  "required_conversation_resolution": true
}
INNEREOF
    then
        echo "✅ Protected $repo ($branch)"
        return 0
    else
        echo "❌ Failed to protect $repo ($branch)"
        return 1
    fi
}

protect_branch "$1" "$2"
WRKEREOF

# ===== MAIN SCRIPT =====
echo "🚀 Starting branch protection..."
check_auth

echo "📜 Processing repositories..."
gh repo list --json nameWithOwner,isPrivate --jq '.[] | select(.isPrivate==false) | .nameWithOwner' 2>/dev/null | \
parallel --will-cite -j "$PARALLEL_JOBS" \
    "bash -c \$'$WORKER_SCRIPT' _ {} main || bash -c \$'$WORKER_SCRIPT' _ {} master"

echo "✨ Done!"
