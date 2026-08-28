#!/bin/zsh

set -euo pipefail

SCRIPT_DIRECTORY="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIRECTORY:h}"
SOURCE_ICON="${PROJECT_ROOT}/assets/app-icon/HealthFirst-AppIcon-master-v2.png"
BUILD_ROOT="${HEALTHFIRST_BUILD_ROOT:-${PROJECT_ROOT}/.build-app}"
MODULE_CACHE_ROOT="${BUILD_ROOT}/icon-module-cache"

if [[ "$#" -ne 1 ]]; then
    print -u2 "用法：Scripts/make-app-icon.sh <输出 .icns 路径>"
    exit 2
fi

OUTPUT_ICON="$1"
if [[ "${OUTPUT_ICON:e:l}" != "icns" ]]; then
    print -u2 "输出文件必须使用 .icns 扩展名：${OUTPUT_ICON}"
    exit 2
fi

if [[ ! -f "${SOURCE_ICON}" ]]; then
    print -u2 "找不到 1024×1024 图标母版：${SOURCE_ICON}"
    exit 1
fi

/bin/mkdir -p "${MODULE_CACHE_ROOT}/clang" "${MODULE_CACHE_ROOT}/swift"

env \
    DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}" \
    CLANG_MODULE_CACHE_PATH="${MODULE_CACHE_ROOT}/clang" \
    SWIFTPM_MODULECACHE_OVERRIDE="${MODULE_CACHE_ROOT}/swift" \
    /usr/bin/swift \
    -module-cache-path "${MODULE_CACHE_ROOT}/swift" \
    "${SCRIPT_DIRECTORY}/make-app-icon.swift" \
    "${SOURCE_ICON}" \
    "${OUTPUT_ICON}"

if [[ ! -s "${OUTPUT_ICON}" ]]; then
    print -u2 "生成完成后没有找到有效 .icns：${OUTPUT_ICON}"
    exit 1
fi

print "已生成：${OUTPUT_ICON}"
