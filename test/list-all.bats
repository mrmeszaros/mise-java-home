#!/usr/bin/env bats

BIN="$BATS_TEST_DIRNAME/../bin/list-all"

@test "returns only 'auto'" {
  run "$BIN"
  [ "$status" -eq 0 ]
  [ "$output" = "auto" ]
}
