#!/usr/bin/env bash
# Test script for enrich_diff_markdown function
# Usage: ./test_enrich_diff.sh [diff_file]

set -euo pipefail

diff_file="${1:-../release/config_changes-vm.diff}"
output_file="${diff_file}.enriched.md"

# Import the enrich_diff_markdown function from kbuild2.sh
source "./kbuild2.sh"

echo "Testing enrich_diff_markdown on $diff_file..."
if enrich_diff_markdown "$diff_file" > "$output_file"; then
    echo "Enrichment succeeded. Output: $output_file"
else
    echo "Enrichment failed. See $output_file for fallback or errors."
fi
