#!/bin/sh
# Markdown Reader — 지정한 디렉터리에서 KDE 기본 터미널 열기
#   1) kdeglobals [General] TerminalApplication (KDE 설정 → 기본 터미널의 Exec 라인)
#   2) kdeglobals [General] TerminalService  (데스크톱 파일 ID → Exec 추출)
#   3) xdg-terminal-exec → konsole → x-terminal-emulator
dir=$1
[ -n "$dir" ] || exit 2
cd -- "$dir" || exit 1

cfg() {
    kreadconfig6 --file kdeglobals --group General --key "$1" 2>/dev/null
}

term=$(cfg TerminalApplication)
if [ -n "$term" ]; then
    setsid sh -c "$term" >/dev/null 2>&1 &
    exit 0
fi

svc=$(cfg TerminalService)
if [ -n "$svc" ]; then
    for base in /usr/share/applications "${XDG_DATA_HOME:-$HOME/.local/share}/applications"; do
        f="$base/$svc"
        if [ -f "$f" ]; then
            line=$(sed -n 's/^Exec=//p' "$f" | head -1 | sed 's/ *%[a-zA-Z]//g')
            if [ -n "$line" ]; then
                setsid sh -c "$line" >/dev/null 2>&1 &
                exit 0
            fi
        fi
    done
fi

for t in xdg-terminal-exec konsole x-terminal-emulator; do
    if command -v "$t" >/dev/null 2>&1; then
        setsid "$t" >/dev/null 2>&1 &
        exit 0
    fi
done

# 메시지는 위젯이 로케일에 맞춰 표시하므로 여기서는 조용히 실패합니다.
exit 1
