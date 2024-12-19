#!/usr/bin/env bash

# ===== TEST CONFIGURATION =====
TEST_REPO="test-protection/test-repo"
SCRIPT_PATH="./scripts/protect-branches.sh"
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# ===== TEST UTILITIES =====
print_header() {
    echo "🧪 Running tests for branch protection script..."
    echo "================================================"
}

print_summary() {
    echo "================================================"
    echo "📊 Test Summary:"
    echo "Total tests: $TOTAL_TESTS"
    echo "✅ Passed: $PASSED_TESTS"
    echo "❌ Failed: $FAILED_TESTS"
    echo "================================================"
}

assert() {
    local message="$1"
    local command="$2"
    local expected_status="$3"

    echo -n "Testing $message... "
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    eval "$command"
    local status=$?

    if [ $status -eq $expected_status ]; then
        echo "✅ Passed"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo "❌ Failed (expected $expected_status, got $status)"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

setup() {
    echo "🔧 Setting up test environment..."
    # Create temporary directory for test artifacts
    TEST_DIR=$(mktemp -d)
    cp "$SCRIPT_PATH" "$TEST_DIR/protect-branches.sh"
    chmod +x "$TEST_DIR/protect-branches.sh"
    cd "$TEST_DIR" || exit 1
}

cleanup() {
    echo "🧹 Cleaning up test environment..."
    cd - >/dev/null || exit 1
    rm -rf "$TEST_DIR"
}

# ===== MOCK FUNCTIONS =====
mock_gh() {
    cat <<EOF > gh
#!/usr/bin/env bash
case "\$*" in
    "auth status")
        echo "Logged in to github.com"
        echo "Token scopes: repo"
        ;;
    *"api /repos/$TEST_REPO"*)
        echo '{"permissions":{"admin":true}}'
        ;;
    *"api /repos/"*"/branches/main"*)
        return 0
        ;;
    *"api /repos/"*"/branches/master"*)
        return 1
        ;;
    "repo list"*)
        echo "$TEST_REPO"
        echo "another-org/another-repo"
        ;;
    *)
        echo "Mock gh: Unknown command: $*"
        return 1
        ;;
esac
EOF
    chmod +x gh
    export PATH="$PWD:$PATH"
}

# ===== TESTS =====
test_auth_check() {
    assert "GitHub authentication check" \
        "source ./protect-branches.sh && check_auth" \
        0
}

test_admin_check() {
    assert "Admin repository check" \
        "source ./protect-branches.sh && is_admin '$TEST_REPO'" \
        0
}

test_exclusion_check() {
    # First source the script
    source ./protect-branches.sh
    # Export the functions
    export -f protect_branch
    export -f spinner
    export -f is_excluded_repo
    export -f is_admin
    # Then run the test
    assert "Repository exclusion check" \
        "EXCLUDED_REPOS='test-protection/test-repo' is_excluded_repo '$TEST_REPO'" \
        0
}

test_branch_protection() {
    assert "Branch protection dry run" \
        "DRY_RUN=true source ./protect-branches.sh && protect_branch '$TEST_REPO' main" \
        0
}

test_parallel_execution() {
    # Source the script to get functions defined first
    source ./protect-branches.sh
    # Export all required functions
    export -f protect_branch
    export -f spinner
    export -f is_excluded_repo
    export -f is_admin
    # Don't try to export gh since it's a script file
    assert "Parallel execution" \
        "PARALLEL_JOBS=2 ./protect-branches.sh" \
        0
}

# ===== MAIN =====
main() {
    print_header
    setup
    mock_gh

    # Run tests
    test_auth_check
    test_admin_check
    test_exclusion_check
    test_branch_protection
    test_parallel_execution

    print_summary
    cleanup

    # Return overall test status
    [ $FAILED_TESTS -eq 0 ]
}

main
