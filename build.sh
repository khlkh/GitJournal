#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 xtcc
#
# SPDX-License-Identifier: MIT
#
# 编译并安装 GitJournal Android APK
#
# 用法:
#   ./build.sh all        编译 prod release 并安装到手机 (默认)
#   ./build.sh build      仅编译
#   ./build.sh install    仅安装到已连接设备
#   ./build.sh dev        编译 dev debug 版并安装 (包名带 .dev 后缀, 可与正式版共存)
#   ./build.sh build -f dev -m debug   自定义 flavor/模式
#
# 依赖: Flutter (默认 ~/flutter/bin), Android SDK (默认 ~/Android/Sdk)
# 可用环境变量覆盖: FLUTTER_BIN, ADB

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUTTER_BIN="${FLUTTER_BIN:-$HOME/flutter/bin}"
ADB="${ADB:-$HOME/Android/Sdk/platform-tools/adb}"
OUT="$ROOT/build/app/outputs/flutter-apk"

FLAVOR="prod"
MODE="release"
CMD="all"

usage() {
  sed -n 's/^# \{0,1\}//p' "$0" | sed -n '/^用法:/,$p'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    build | install | all) CMD="$1"; shift ;;
    dev) CMD="all"; FLAVOR="dev"; MODE="debug"; shift ;;
    -f) FLAVOR="$2"; shift 2 ;;
    -m) MODE="$2"; shift 2 ;;
    -h | --help) usage; exit 0 ;;
    *) echo "未知参数: $1"; usage; exit 1 ;;
  esac
done

[[ -x "$FLUTTER_BIN/flutter" ]] || { echo "错误: 未找到 Flutter ($FLUTTER_BIN/flutter)，可用 FLUTTER_BIN 指定"; exit 1; }
[[ -x "$ADB" ]] || { echo "错误: 未找到 adb ($ADB)，可用 ADB 指定"; exit 1; }

build() {
  echo "==> 编译: flutter build apk --flavor $FLAVOR --$MODE"
  "$FLUTTER_BIN/flutter" build apk --flavor "$FLAVOR" --"$MODE"
}

install_apk() {
  if [[ "$MODE" == "debug" ]]; then
    APK="$OUT/app-${FLAVOR}-debug.apk"
  else
    APK="$OUT/app-${FLAVOR}-release.apk"
  fi
  [[ -f "$APK" ]] || { echo "错误: APK 不存在 ($APK)，请先运行 ./build.sh build"; exit 1; }

  local devices
  devices="$("$ADB" devices | awk 'NR>1 && $2=="device" {print $1}')"
  [[ -n "$devices" ]] || { echo "错误: 未检测到已连接设备 (adb devices)"; exit 1; }
  echo "==> 安装到设备: $devices"
  "$ADB" install -r "$APK" || {
    echo "安装失败。常见原因:"
    echo "  - INSTALL_FAILED_USER_RESTRICTED: 请在手机上点击授权弹窗后重试"
    echo "  - INSTALL_FAILED_VERSION_DOWNGRADE: 设备上版本号更新, 请先卸载旧版或改用 ./build.sh dev"
    exit 1
  }
  echo "==> 已安装: $APK"
}

case "$CMD" in
  build) build ;;
  install) install_apk ;;
  all) build && install_apk ;;
esac
