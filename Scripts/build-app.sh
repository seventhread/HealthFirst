#!/bin/zsh

set -euo pipefail

SCRIPT_DIRECTORY="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIRECTORY:h}"
CONFIGURATION="${1:-debug}"
XCODE_DEVELOPER_PATH="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
BUILD_ROOT="${PROJECT_ROOT}/.build-app"
SWIFTPM_BUILD_ROOT="${BUILD_ROOT}/swiftpm"
MODULE_CACHE_ROOT="${BUILD_ROOT}/module-cache"
APP_BUNDLE="${BUILD_ROOT}/HealthFirst.app"
CONTENTS_DIRECTORY="${APP_BUNDLE}/Contents"

if [[ "${CONFIGURATION}" != "debug" && "${CONFIGURATION}" != "release" ]]; then
    print -u2 "用法：Scripts/build-app.sh [debug|release]"
    exit 2
fi

if [[ ! -d "${XCODE_DEVELOPER_PATH}" ]]; then
    print -u2 "找不到 Xcode 开发目录：${XCODE_DEVELOPER_PATH}"
    exit 1
fi

mkdir -p \
    "${CONTENTS_DIRECTORY}/MacOS" \
    "${CONTENTS_DIRECTORY}/Resources" \
    "${MODULE_CACHE_ROOT}"

env \
    DEVELOPER_DIR="${XCODE_DEVELOPER_PATH}" \
    CLANG_MODULE_CACHE_PATH="${MODULE_CACHE_ROOT}/clang" \
    SWIFTPM_MODULECACHE_OVERRIDE="${MODULE_CACHE_ROOT}/swiftpm" \
    swift build \
        --disable-sandbox \
        --configuration "${CONFIGURATION}" \
        --scratch-path "${SWIFTPM_BUILD_ROOT}"

BIN_DIRECTORY="$(
    env \
        DEVELOPER_DIR="${XCODE_DEVELOPER_PATH}" \
        CLANG_MODULE_CACHE_PATH="${MODULE_CACHE_ROOT}/clang" \
        SWIFTPM_MODULECACHE_OVERRIDE="${MODULE_CACHE_ROOT}/swiftpm" \
        swift build \
            --disable-sandbox \
            --configuration "${CONFIGURATION}" \
            --scratch-path "${SWIFTPM_BUILD_ROOT}" \
            --show-bin-path
)"

/bin/cp \
    "${BIN_DIRECTORY}/HealthFirst" \
    "${CONTENTS_DIRECTORY}/MacOS/HealthFirst"

RESOURCE_BUNDLE_NAME="HealthFirst_HealthFirstApp.bundle"
RESOURCE_BUNDLE_SOURCE="${BIN_DIRECTORY}/${RESOURCE_BUNDLE_NAME}"
RESOURCE_BUNDLE_DESTINATION="${CONTENTS_DIRECTORY}/Resources/${RESOURCE_BUNDLE_NAME}"

if [[ ! -d "${RESOURCE_BUNDLE_SOURCE}" ]]; then
    print -u2 "找不到角色资源包：${RESOURCE_BUNDLE_SOURCE}"
    exit 1
fi

/usr/bin/ditto \
    "${RESOURCE_BUNDLE_SOURCE}" \
    "${RESOURCE_BUNDLE_DESTINATION}"

/bin/cp \
    "${PROJECT_ROOT}/Support/HealthFirst-Info.plist" \
    "${CONTENTS_DIRECTORY}/Info.plist"

/usr/bin/plutil -lint "${CONTENTS_DIRECTORY}/Info.plist"
/usr/bin/codesign --force --deep --sign - "${APP_BUNDLE}"

print "已生成：${APP_BUNDLE}"
print "运行：open \"${APP_BUNDLE}\""
