#!/usr/bin/env bats

setup() {
  export JAVA_HOME_CMD="$BATS_TEST_DIRNAME/mock_java_home"
  EXEC_ENV="$BATS_TEST_DIRNAME/../bin/exec-env"
  cd "$BATS_TEST_TMPDIR"
  unset JAVA_VERSION JAVA_VENDOR JAVA_HOME JAVA_ARCH
}

# Helper: source exec-env (suppressing its own debug output), then call debug_log
# with the given env vars and capture only that call's stderr output.
run_debug_log() {
  env "$@" bash -c "
    source '$EXEC_ENV' 2>/dev/null
    debug_log 'test message'
  " 2>&1 >/dev/null
}

@test "debug_log: no output when MISE_DEBUG is unset" {
  result=$(run_debug_log)
  [ "$result" = "" ]
}

@test "debug_log: plain output when MISE_DEBUG set and no colour flags" {
  result=$(run_debug_log MISE_DEBUG=1)
  [ "$result" = "DEBUG [java-home] test message" ]
}

@test "debug_log: plain output when MISE_COLOR=0" {
  result=$(run_debug_log MISE_DEBUG=1 MISE_COLOR=0)
  [ "$result" = "DEBUG [java-home] test message" ]
}

@test "debug_log: plain output when NO_COLOR set" {
  result=$(run_debug_log MISE_DEBUG=1 NO_COLOR=1)
  [ "$result" = "DEBUG [java-home] test message" ]
}

@test "debug_log: plain output when MISE_COLOR=1 but no TTY" {
  result=$(run_debug_log MISE_DEBUG=1 MISE_COLOR=1)
  [ "$result" = "DEBUG [java-home] test message" ]
}

@test "debug_log: NO_COLOR takes precedence over MISE_COLOR=1" {
  result=$(run_debug_log MISE_DEBUG=1 MISE_COLOR=1 NO_COLOR=1)
  [ "$result" = "DEBUG [java-home] test message" ]
}
