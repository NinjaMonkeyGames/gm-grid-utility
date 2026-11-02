#!/bin/bash

LOG_FILE="$1"

if [ -z "$LOG_FILE" ] || [ ! -f "$LOG_FILE" ]; then
  echo "Error: Log file not provided or does not exist."
  exit 1
fi

# 1. Any failed assertion. Print the matching lines (with line numbers) so the log shows WHICH test failed.
if grep -n "\[FAIL\]" "$LOG_FILE"; then
  echo "Test failure detected: [FAIL] found in output."
  exit 1
fi

# 2. A runtime crash never prints [FAIL], so it would otherwise look like a pass.
if grep -n "FATAL ERROR" "$LOG_FILE"; then
  echo "Runtime error detected: FATAL ERROR found in output."
  exit 1
fi

# 3. The tests must actually have run to the end and reported zero failures.
#    (If obj_unit_test was never created, e.g. CI unset, there would be no [FAIL] either.)
if ! grep -q "UNIT TESTS COMPLETE: [0-9]* passed, 0 failed" "$LOG_FILE"; then
  echo "Tests did not complete: summary line with 0 failures not found in output."
  exit 1
fi

echo "No failures found. Tests passed successfully."
exit 0