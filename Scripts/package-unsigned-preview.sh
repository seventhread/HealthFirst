#!/bin/zsh

set -euo pipefail

SCRIPT_DIRECTORY="${0:A:h}"
PROJECT_ROOT="${SCRIPT_DIRECTORY:h}"
INFO_PLIST="${PROJECT_ROOT}/Support/HealthFirst-Info.plist"
DIST_DIRECTORY="${PROJECT_ROOT}/dist"
TEMP_BASE="${TMPDIR:-/tmp}"

if [[ ! -f "${INFO_PLIST}" ]]; then
    print -u2 "找不到版本信息：${INFO_PLIST}"
    exit 1
fi

VERSION="$(/usr/bin/plutil -extract CFBundleShortVersionString raw "${INFO_PLIST}")"
BUILD_NUMBER="$(/usr/bin/plutil -extract CFBundleVersion raw "${INFO_PLIST}")"

if [[ -z "${VERSION}" || "${VERSION}" == *[^0-9A-Za-z._-]* ]]; then
    print -u2 "Info.plist 中的版本号不能安全用于文件名：${VERSION}"
    exit 1
fi

TEMP_BUILD_ROOT="$(/usr/bin/mktemp -d "${TEMP_BASE%/}/healthfirst-unsigned.XXXXXX")"

cleanup() {
    if [[ -n "${TEMP_BUILD_ROOT:-}" && -d "${TEMP_BUILD_ROOT}" ]]; then
        /bin/rm -rf -- "${TEMP_BUILD_ROOT}"
    fi
}
trap cleanup EXIT

print "正在构建 HealthFirst ${VERSION} (${BUILD_NUMBER}) 的 ad-hoc 测试预览……"
env \
    HEALTHFIRST_BUILD_ROOT="${TEMP_BUILD_ROOT}" \
    "${SCRIPT_DIRECTORY}/build-app.sh" release

APP_BUNDLE="${TEMP_BUILD_ROOT}/HealthFirst.app"
APP_BINARY="${APP_BUNDLE}/Contents/MacOS/HealthFirst"

if [[ ! -x "${APP_BINARY}" ]]; then
    print -u2 "构建完成后未找到可执行文件：${APP_BINARY}"
    exit 1
fi

/usr/bin/codesign --verify --deep --strict "${APP_BUNDLE}"
SIGNATURE_INFO="$(/usr/bin/codesign -dv --verbose=4 "${APP_BUNDLE}" 2>&1)"
if [[ "${SIGNATURE_INFO}" != *"Signature=adhoc"* ]]; then
    print -u2 "预期得到 ad-hoc 签名，但签名检查结果不一致；已停止打包。"
    exit 1
fi

ARCHITECTURES="$(/usr/bin/lipo -archs "${APP_BINARY}")"
case "${ARCHITECTURES}" in
    "arm64")
        ARCHITECTURE_LABEL="apple-silicon"
        ;;
    "x86_64")
        ARCHITECTURE_LABEL="intel"
        ;;
    *"arm64"*"x86_64"*|*"x86_64"*"arm64"*)
        ARCHITECTURE_LABEL="universal"
        ;;
    *)
        ARCHITECTURE_LABEL="${ARCHITECTURES// /-}"
        ;;
esac

ARCHIVE_NAME="HealthFirst-v${VERSION}-unsigned-macos-${ARCHITECTURE_LABEL}.zip"
CHECKSUM_NAME="${ARCHIVE_NAME}.sha256"
ARCHIVE_PATH="${DIST_DIRECTORY}/${ARCHIVE_NAME}"
CHECKSUM_PATH="${DIST_DIRECTORY}/${CHECKSUM_NAME}"

/bin/mkdir -p "${DIST_DIRECTORY}"

if [[ -e "${ARCHIVE_PATH}" || -e "${CHECKSUM_PATH}" ]]; then
    print -u2 "目标文件已存在。为避免覆盖，请先人工确认并移走："
    print -u2 "  ${ARCHIVE_PATH}"
    print -u2 "  ${CHECKSUM_PATH}"
    exit 1
fi

/usr/bin/ditto \
    -c \
    -k \
    --keepParent \
    --sequesterRsrc \
    "${APP_BUNDLE}" \
    "${ARCHIVE_PATH}"

HASH="$(/usr/bin/shasum -a 256 "${ARCHIVE_PATH}")"
HASH="${HASH%% *}"
print -r -- "${HASH}  ${ARCHIVE_NAME}" > "${CHECKSUM_PATH}"

(
    cd "${DIST_DIRECTORY}"
    /usr/bin/shasum -a 256 -c "${CHECKSUM_NAME}"
)

print ""
print "已生成未签名测试预览："
print "  ${ARCHIVE_PATH}"
print "  ${CHECKSUM_PATH}"
print ""
print -u2 "警告：此包只有 ad-hoc 签名，未经过 Apple Developer ID 签名或公证。"
print -u2 "它仅用于知情测试者，不应标记为正式稳定版。"
