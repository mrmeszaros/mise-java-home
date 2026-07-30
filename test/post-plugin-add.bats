#!/usr/bin/env bats

BIN="$BATS_TEST_DIRNAME/../bin/post-plugin-add"

@test "creates the auto marker directory" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  run env MISE_DATA_DIR="$tmpdir" "$BIN"
  [ "$status" -eq 0 ]
  [ -d "$tmpdir/installs/java-home/auto" ]
  rm -rf "$tmpdir"
}

@test "is idempotent when marker already exists" {
  local tmpdir
  tmpdir="$(mktemp -d)"
  env MISE_DATA_DIR="$tmpdir" "$BIN"
  run env MISE_DATA_DIR="$tmpdir" "$BIN"
  [ "$status" -eq 0 ]
  rm -rf "$tmpdir"
}
