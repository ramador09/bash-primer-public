# tools/check.sh — the validation gate for "Introduction to the Bash Shell".
#
# This is the bash analogue of ECP's `ecp.validate(..., strict=True)`. Source it
# (in a hidden cell) at the top of every notebook:
#
#     source tools/check.sh
#
# Then assert results with a test expression and a human-readable message:
#
#     check "test -f notes.txt"            "notes.txt was created"
#     check '[ -n "$USER" ]'               "the USER variable is set"
#     check 'echo "$out" | grep -qE "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"' "date is ISO 8601"
#
# On success it prints a green ✓ and the message and returns 0.
# On failure it prints a red ✗, the message, and the failing expression, then
# returns non-zero. Because every validation cell *ends* with its `check` call,
# a failure makes the cell exit non-zero — and bash_kernel reports a non-zero
# exit as a cell error, so `nbconvert --execute` (allow_errors: false) fails the
# build. A wrong result therefore breaks CI exactly as it does in ECP.
#
# Keep assertions about *what a command did*, not about reproducing its work:
# run the command in the solution cell, capture what you need, then `check` it.

# ANSI colours. nbconvert captures the cell's stdout/stderr and Jupyter Book
# renders the escape codes as coloured spans, so the ✓/✗ show green/red on the
# published page; in a plain terminal they colourise too. Harmless if ignored.
_BP_GREEN=$'\033[1;32m'
_BP_RED=$'\033[1;31m'
_BP_DIM=$'\033[2m'
_BP_RESET=$'\033[0m'

# A per-session counter, in case a notebook wants to assert "all checks passed"
# at the end. Reset on every source of this file.
_BP_CHECKS_FAILED=0

check() {
    local test_expr="$1"
    local message="${2:-$1}"

    if eval "$test_expr" >/dev/null 2>&1; then
        printf '%s✓%s %s\n' "$_BP_GREEN" "$_BP_RESET" "$message"
        return 0
    fi

    _BP_CHECKS_FAILED=$(( _BP_CHECKS_FAILED + 1 ))
    # Failure goes to stderr (Jupyter renders it on a red ground) and returns
    # non-zero so the cell — and the build — fails.
    printf '%s✗%s %s  %s(failed: %s)%s\n' \
        "$_BP_RED" "$_BP_RESET" "$message" "$_BP_DIM" "$test_expr" "$_BP_RESET" >&2
    return 1
}
