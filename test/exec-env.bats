#!/usr/bin/env bats

MOCK="$BATS_TEST_DIRNAME/mock/usr/libexec/java_home"
BIN="$BATS_TEST_DIRNAME/../bin/exec-env"

@test "sets JAVA_HOME with version and arch" {
  result=$(env JAVA_HOME_CMD="$MOCK" JAVA_VERSION="17.0.18" JAVA_ARCH="x86_64" bash -c "source '$BIN'; echo \$JAVA_HOME")
  [ "$result" = "/jvms/zulu-17-x86_64/Contents/Home" ]
}

@test "sets JAVA_HOME with version only" {
  result=$(env JAVA_HOME_CMD="$MOCK" JAVA_VERSION="17" bash -c "source '$BIN'; echo \$JAVA_HOME")
  [ "$result" = "/jvms/zulu-17-arm64/Contents/Home" ]
}

@test "sets JAVA_HOME with arch only" {
  result=$(env JAVA_HOME_CMD="$MOCK" JAVA_ARCH="x86_64" bash -c "source '$BIN'; echo \$JAVA_HOME")
  [ "$result" = "/jvms/zulu-17-x86_64/Contents/Home" ]
}

@test "sets JAVA_HOME with no args, using system default" {
  result=$(env JAVA_HOME_CMD="$MOCK" bash -c "source '$BIN'; echo \$JAVA_HOME")
  [ "$result" = "/jvms/azul-20.0.2-aarch64/Contents/Home" ]
}
