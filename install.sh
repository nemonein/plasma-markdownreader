#!/usr/bin/env bash
# Markdown Reader — Plasma 6 widget installer
#   ./install.sh        installs for the current user on this machine
set -euo pipefail

PLUGIN_ID="com.github.plasma-markdownreader"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/markdownreader"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DEST_DIR="$DATA_HOME/plasma/plasmoids/$PLUGIN_ID"

# Korean only when the system locale is Korean; English otherwise.
LOCALE_NAME="${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}"
case "$LOCALE_NAME" in
    ko*|KO*) IS_KO=1 ;;
    *) IS_KO=0 ;;
esac

msg() {
    if [ "$IS_KO" -eq 1 ]; then
        printf '%s\n' "$1"
    else
        printf '%s\n' "$2"
    fi
}

err() {
    if [ "$IS_KO" -eq 1 ]; then
        printf '%s\n' "$1" >&2
    else
        printf '%s\n' "$2" >&2
    fi
}

if [ ! -d "$SRC_DIR" ]; then
    err "패키지 폴더를 찾지 못했습니다: $SRC_DIR" "Package folder not found: $SRC_DIR"
    exit 1
fi

if command -v kpackagetool6 >/dev/null 2>&1; then
    if [ -d "$DEST_DIR" ]; then
        # Drop config pages left behind by older versions: Plasma would keep
        # loading them and show an empty settings tab.
        rm -f "$DEST_DIR/contents/config/config.qml"
        rm -f "$DEST_DIR/contents/config/configGeneral.qml"
        rm -f "$DEST_DIR/contents/config/configGeneralMinimal.qml"
        kpackagetool6 --type Plasma/Applet --upgrade "$SRC_DIR"
    else
        kpackagetool6 --type Plasma/Applet --install "$SRC_DIR"
    fi
else
    err "kpackagetool6가 없어 파일을 직접 복사합니다." "kpackagetool6 not found; copying files directly."
    mkdir -p "$DEST_DIR"
    rm -f "$DEST_DIR/contents/config/config.qml"
    rm -f "$DEST_DIR/contents/config/configGeneral.qml"
    rm -f "$DEST_DIR/contents/config/configGeneralMinimal.qml"
    cp -r "$SRC_DIR"/. "$DEST_DIR"/
fi

msg "" ""
msg "설치 완료." "Installation complete."
msg "" ""
msg "다음 단계" "Next steps"
msg "  1) 데스크톱(또는 패널) 우클릭 → 위젯 추가 → \"Markdown Reader\" 추가" "  1) Right-click the desktop or panel → Add Widgets → \"Markdown Reader\""
msg "  2) 위젯 본문의 경로 입력칸에 폴더를 넣고 Enter (예: ~/Documents)" "  2) Enter a folder in the widget's path field and press Enter (e.g. ~/Documents)"
msg "  3) 헤더 ⚙ 로 폴더·정렬·글자 크기 변경" "  3) Use the ⚙ button in the header to change folder, sorting and font size"
msg "  4) 좌우 화살표 키 또는 헤더의 ‹ › 버튼으로 문서 이동" "  4) Move between documents with ← → or the ‹ › buttons"
msg "" ""
msg "화면에 바로 반영되지 않으면:" "If the widget does not show up right away:"
msg "  kquitapp6 plasmashell && kstart plasmashell" "  kquitapp6 plasmashell && kstart plasmashell"
