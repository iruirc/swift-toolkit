#!/usr/bin/env bash
set -euo pipefail

violations=0
for en in skills/*/locales/en.md; do
  dir=$(dirname "$en")
  ru="$dir/ru.md"
  if [ ! -f "$ru" ]; then
    echo "Missing ru.md next to $en"
    violations=$((violations + 1))
    continue
  fi

  diff_out=$(diff <(grep '^## ' "$en" | sort) <(grep '^## ' "$ru" | sort) || true)
  if [ -n "$diff_out" ]; then
    echo "Key parity mismatch in $dir/:"
    echo "$diff_out"
    violations=$((violations + 1))
  fi
done

if [ "$violations" -gt 0 ]; then
  echo
  echo "Locale parity lint failed: $violations issue(s)"
  exit 1
fi

echo "Locale parity lint passed: all locales in sync"
