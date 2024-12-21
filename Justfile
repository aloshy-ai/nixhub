# Justfile

# List all available just commands
default:
   @just --list

# Run tests
test:
   ./scripts/tests/*.test
