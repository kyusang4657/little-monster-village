#!/bin/bash
# Godot 편집기 메뉴 "Project → Install Android Build Template" 와 같은 일을 터미널에서 한다.
# 설치된 내보내기 템플릿(android_source.zip)을 android/build 에 풀고 버전 표식을 쓴다. Gradle 빌드(AAB)에 필요하다.
# 사용: tools/install_android_template.sh [템플릿 폴더]   (기본: ~/.local/share/godot/export_templates/4.4.1.stable)
set -e
cd "$(dirname "$0")/.."
T="${1:-$HOME/.local/share/godot/export_templates/4.4.1.stable}"
if [ ! -f "$T/android_source.zip" ]; then
  echo "android_source.zip 이 없습니다: $T  (Godot 내보내기 템플릿(.tpz)을 설치하거나 폴더를 인자로 주세요)"; exit 1
fi
rm -rf android/build
mkdir -p android/build
unzip -q "$T/android_source.zip" -d android/build
touch android/build/.gdignore   # 편집기가 템플릿 안의 복사본을 가져오지 않도록(중복 class_name 오류 방지)
cat "$T/version.txt" > android/.build_version
echo "android/build 에 템플릿 $(cat android/.build_version) 설치"
