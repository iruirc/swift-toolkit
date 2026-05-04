#!/usr/bin/env bats
load "$(dirname "$BATS_TEST_FILENAME")/../helpers/ws-test-helpers"

setup() { WS_TEST_TMPDIRS=(); }
teardown() { ws_cleanup_tmpdirs; }

@test "docs-regen rewrites PKG_LIST section, preserves manual content" {
  local parent="$(ws_mktemp_dir)"
  "$(ws_repo_root)/tests/foundation/helpers/ws-init-driver.zsh" \
    "$(ws_fixture_path workspace-yml/grouped.yml)" "$parent" >&2

  # Inject stale content into the EXISTING marker section, then add manual content outside.
  local readme="$parent/GroupedWS-meta/README.md"
  # Replace the existing empty marker section with stale content via wsmark::write itself
  zsh -c "source '$(ws_lib_path workspace-doc-markers.zsh)'; printf '%s\n' 'stale-bogus' | wsmark::write '$readme' PKG_LIST"
  echo "MANUAL_OUTSIDE_MARKERS" >> "$readme"

  run "$(ws_repo_root)/tests/foundation/helpers/ws-docs-regen-driver.zsh" "$parent/GroupedWS-meta"
  [ "$status" -eq 0 ]

  run grep '^- AKit (api-contract)' "$readme"
  [ "$status" -eq 0 ]
  run grep "^stale-bogus$" "$readme"
  [ "$status" -eq 1 ]
  run grep '^MANUAL_OUTSIDE_MARKERS$' "$readme"
  [ "$status" -eq 0 ]
}
