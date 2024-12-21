# Justfile

# List all available just commands
default:
   @just --list

# Run tests
test:
    for file in ./scripts/tests/*.test; do $file; done
