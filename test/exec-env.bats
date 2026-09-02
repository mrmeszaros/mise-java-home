#!/usr/bin/env bats

setup() {
  export JAVA_HOME_CMD="$BATS_TEST_DIRNAME/mock_java_home"
  EXEC_ENV="$BATS_TEST_DIRNAME/../bin/exec-env"
  cd "$BATS_TEST_TMPDIR"
  unset JAVA_VERSION JAVA_VENDOR JAVA_HOME JAVA_ARCH
}

@test "sets JAVA_HOME with version and arch" {
  JAVA_VERSION="17.0.18" JAVA_ARCH="x86_64" source "$EXEC_ENV"
  [ "$JAVA_HOME" = "/jvms/zulu-17-x86_64/Contents/Home" ]
}

# ── .sdkmanrc fallback ───────────────────────────────────────────────────────

@test ".sdkmanrc: zulu vendor — uses major version only, sets JAVA_VENDOR" {
  echo "java=25.0.3-zulu" > .sdkmanrc
  JAVA_ARCH="arm64" source "$EXEC_ENV"
  [ "$JAVA_HOME"   = "/jvms/zulu-25-arm64/Contents/Home" ]
  [ "$JAVA_VENDOR" = "zulu" ]
}

@test ".sdkmanrc: non-zulu vendor (tem) — uses full version, sets JAVA_VENDOR" {
  echo "java=21.0.4-tem" > .sdkmanrc
  JAVA_ARCH="arm64" source "$EXEC_ENV"
  [ "$JAVA_HOME"   = "/jvms/temurin-21.0.4-arm64/Contents/Home" ]
  [ "$JAVA_VENDOR" = "tem" ]
}

@test ".sdkmanrc: no vendor suffix — uses version, JAVA_VENDOR unset" {
  echo "java=21" > .sdkmanrc
  JAVA_ARCH="arm64" source "$EXEC_ENV"
  [ "$JAVA_HOME"   = "/jvms/zulu-21-arm64/Contents/Home" ]
  [ "$JAVA_VENDOR" = "" ]
}

@test ".sdkmanrc: no java= line — falls through to system default" {
  echo "scala=3.3.0" > .sdkmanrc
  JAVA_ARCH="arm64" source "$EXEC_ENV"
  [ "$JAVA_HOME" = "/jvms/system-default/Contents/Home" ]
}

@test ".sdkmanrc: JAVA_VERSION env wins over .sdkmanrc" {
  echo "java=25.0.3-zulu" > .sdkmanrc
  JAVA_VERSION="17" JAVA_ARCH="arm64" source "$EXEC_ENV"
  [ "$JAVA_HOME" = "/jvms/zulu-17-arm64/Contents/Home" ]
}

# ── .java-version fallback ───────────────────────────────────────────────────

@test ".java-version: uses version, JAVA_VENDOR unset" {
  echo "21" > .java-version
  JAVA_ARCH="arm64" source "$EXEC_ENV"
  [ "$JAVA_HOME"   = "/jvms/zulu-21-arm64/Contents/Home" ]
  [ "$JAVA_VENDOR" = "" ]
}

@test ".java-version: JAVA_VERSION env wins over .java-version" {
  echo "21" > .java-version
  JAVA_VERSION="17" JAVA_ARCH="arm64" source "$EXEC_ENV"
  [ "$JAVA_HOME" = "/jvms/zulu-17-arm64/Contents/Home" ]
}

# ── Priority: .sdkmanrc beats .java-version ──────────────────────────────────

@test ".sdkmanrc takes priority over .java-version when both present" {
  echo "java=25.0.3-zulu" > .sdkmanrc
  echo "21" > .java-version
  JAVA_ARCH="arm64" source "$EXEC_ENV"
  [ "$JAVA_HOME" = "/jvms/zulu-25-arm64/Contents/Home" ]
}

# ── java_home defaulting (assumptions about /usr/libexec/java_home) ──────────
# These verify behaviour we rely on but do not implement.
# If these fail, the real binary changed behaviour — not our code.

@test "java_home: no version, no arch — returns system default" {
  source "$EXEC_ENV"
  [ "$JAVA_HOME" = "/jvms/system-default/Contents/Home" ]
}

@test "java_home: version only — defaults to arm64" {
  JAVA_VERSION="17" source "$EXEC_ENV"
  [ "$JAVA_HOME" = "/jvms/zulu-17-arm64/Contents/Home" ]
}

@test "java_home: arch only — picks highest version for arch" {
  JAVA_ARCH="x86_64" source "$EXEC_ENV"
  [ "$JAVA_HOME" = "/jvms/zulu-17-x86_64/Contents/Home" ]
}
