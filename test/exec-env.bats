#!/usr/bin/env bats

setup() {
  export JAVA_HOME_CMD="$BATS_TEST_DIRNAME/mock/usr/libexec/java_home"
  EXEC_ENV="$BATS_TEST_DIRNAME/../bin/exec-env"
  cd "$BATS_TEST_TMPDIR"
  unset JAVA_VERSION JAVA_VENDOR JAVA_HOME JAVA_ARCH
}

# Helper: source exec-env in a subshell from cwd and print JAVA_HOME and JAVA_VENDOR.
run_exec_env() {
  env "$@" bash -c "source '$EXEC_ENV'; echo \$JAVA_HOME; echo \$JAVA_VENDOR"
}

# ── Existing: explicit env vars ──────────────────────────────────────────────

@test "sets JAVA_HOME with version and arch" {
  result=$(run_exec_env JAVA_VERSION="17.0.18" JAVA_ARCH="x86_64" | sed -n '1p')
  [ "$result" = "/jvms/zulu-17-x86_64/Contents/Home" ]
}

@test "sets JAVA_HOME with version only" {
  result=$(run_exec_env JAVA_VERSION="17" | sed -n '1p')
  [ "$result" = "/jvms/zulu-17-arm64/Contents/Home" ]
}

@test "sets JAVA_HOME with arch only" {
  result=$(run_exec_env JAVA_ARCH="x86_64" | sed -n '1p')
  [ "$result" = "/jvms/zulu-17-x86_64/Contents/Home" ]
}

@test "sets JAVA_HOME with no args, using system default" {
  result=$(run_exec_env | sed -n '1p')
  [ "$result" = "/jvms/azul-20.0.2-aarch64/Contents/Home" ]
}

# ── .sdkmanrc fallback ───────────────────────────────────────────────────────

@test ".sdkmanrc: zulu vendor — uses major version only, sets JAVA_VENDOR" {
  echo "java=25.0.3-zulu" > .sdkmanrc
  result=$(run_exec_env)
  java_home=$(echo "$result" | sed -n '1p')
  java_vendor=$(echo "$result" | sed -n '2p')
  [ "$java_home" = "/jvms/zulu-25-arm64/Contents/Home" ]
  [ "$java_vendor" = "zulu" ]
}

@test ".sdkmanrc: non-zulu vendor (tem) — uses full version, sets JAVA_VENDOR" {
  echo "java=21.0.4-tem" > .sdkmanrc
  result=$(run_exec_env)
  java_home=$(echo "$result" | sed -n '1p')
  java_vendor=$(echo "$result" | sed -n '2p')
  [ "$java_home" = "/jvms/temurin-21.0.4-arm64/Contents/Home" ]
  [ "$java_vendor" = "tem" ]
}

@test ".sdkmanrc: no vendor suffix — uses version, JAVA_VENDOR unset" {
  echo "java=21" > .sdkmanrc
  result=$(run_exec_env)
  java_home=$(echo "$result" | sed -n '1p')
  java_vendor=$(echo "$result" | sed -n '2p')
  [ "$java_home" = "/jvms/zulu-21-arm64/Contents/Home" ]
  [ "$java_vendor" = "" ]
}

@test ".sdkmanrc: no java= line — falls through to system default" {
  echo "scala=3.3.0" > .sdkmanrc
  result=$(run_exec_env | sed -n '1p')
  [ "$result" = "/jvms/azul-20.0.2-aarch64/Contents/Home" ]
}

@test ".sdkmanrc: JAVA_VERSION env wins over .sdkmanrc" {
  echo "java=25.0.3-zulu" > .sdkmanrc
  result=$(run_exec_env JAVA_VERSION="17" | sed -n '1p')
  [ "$result" = "/jvms/zulu-17-arm64/Contents/Home" ]
}

# ── .java-version fallback ───────────────────────────────────────────────────

@test ".java-version: uses version, JAVA_VENDOR unset" {
  echo "21" > .java-version
  result=$(run_exec_env)
  java_home=$(echo "$result" | sed -n '1p')
  java_vendor=$(echo "$result" | sed -n '2p')
  [ "$java_home" = "/jvms/zulu-21-arm64/Contents/Home" ]
  [ "$java_vendor" = "" ]
}

@test ".java-version: JAVA_VERSION env wins over .java-version" {
  echo "21" > .java-version
  result=$(run_exec_env JAVA_VERSION="17" | sed -n '1p')
  [ "$result" = "/jvms/zulu-17-arm64/Contents/Home" ]
}

# ── Priority: .sdkmanrc beats .java-version ──────────────────────────────────

@test ".sdkmanrc takes priority over .java-version when both present" {
  echo "java=25.0.3-zulu" > .sdkmanrc
  echo "21" > .java-version
  result=$(run_exec_env | sed -n '1p')
  [ "$result" = "/jvms/zulu-25-arm64/Contents/Home" ]
}
