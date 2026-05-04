#!/usr/bin/env bats
load "$(dirname "$BATS_TEST_FILENAME")/../helpers/ws-test-helpers"

setup() { WS_TEST_TMPDIRS=(); }
teardown() { ws_cleanup_tmpdirs; }

@test "ws-init-driver creates meta-repo + per-package dirs from grouped.yml" {
  local parent="$(ws_mktemp_dir)"
  run "$(ws_repo_root)/tests/foundation/helpers/ws-init-driver.zsh" \
    "$(ws_fixture_path workspace-yml/grouped.yml)" "$parent"
  [ "$status" -eq 0 ]
  [ -d "$parent/GroupedWS-meta/.git" ]
  [ -f "$parent/GroupedWS-meta/workspace.yml" ]
  [ -f "$parent/GroupedWS-meta/README.md" ]
  [ -f "$parent/commonPackages/AKit/Package.swift" ]
  [ -f "$parent/commonPackages/AKit/CLAUDE.md" ]
  # NEW: verify nested source/test stubs are rendered
  [ -f "$parent/commonPackages/AKit/Sources/AKit/AKit.swift" ]
  [ -f "$parent/commonPackages/AKit/Tests/AKitTests/AKitTests.swift" ]
  # NEW: verify interpolation worked (no raw placeholder remains)
  run grep -F '{{PACKAGE_NAME}}' "$parent/commonPackages/AKit/Sources/AKit/AKit.swift"
  [ "$status" -eq 1 ]
  [ -f "$parent/domainPackages/CFeature/Package.swift" ]
  [ -d "$parent/commonPackages/AKit/.git" ]
}

@test "generated package builds with swift build (sanity)" {
  if ! command -v swift >/dev/null 2>&1; then
    skip "swift not on PATH"
  fi
  local parent="$(ws_mktemp_dir)"
  run "$(ws_repo_root)/tests/foundation/helpers/ws-init-driver.zsh" \
    "$(ws_fixture_path workspace-yml/grouped.yml)" "$parent"
  [ "$status" -eq 0 ]
  cd "$parent/commonPackages/AKit"
  run swift build
  [ "$status" -eq 0 ]
}

@test "ws-init-driver fails on cyclic.yml" {
  local parent="$(ws_mktemp_dir)"
  run "$(ws_repo_root)/tests/foundation/helpers/ws-init-driver.zsh" \
    "$(ws_fixture_path workspace-yml/cyclic.yml)" "$parent"
  [ "$status" -ne 0 ]
}
