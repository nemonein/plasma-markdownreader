# Markdown Reader — KDE Plasma 6 위젯

지정한 폴더의 Markdown 파일을 **한 번에 하나씩, 좌우로 넘기며** 읽기 전용으로 보는 위젯입니다.
편집 기능은 없습니다.
저 혼자 쓰려고 AI 도움을 받아 만든 프로그램입니다.
혹시 필요하신 분 있으실까 하여 올려둡니다.

- 대상: Plasma 6.8 / Qt 6 / KDE Frameworks 6
- C++ 빌드 없음 — QML 패키지 하나이고 `kpackagetool6`로 설치합니다.

## 설치

```bash
git clone https://github.com/nemonein/plasma-markdownreader.git
cd plasma-markdownreader
./install.sh
systemctl --user restart plasma-plasmashell.service
또는,
kquitapp6 plasmashell && kstart plasmashell
```

그다음 데스크톱(또는 패널) 우클릭 → **위젯 추가** → "Markdown Reader"를 끌어다 놓습니다.

> 설정은 **위젯 안에서** 합니다(아래 "설정" 항목).
> KDE 설정 대화상자의 카테고리 페이지는 이 패키지에서 제거했습니다 — "알려진 문제" 참고.

## 설정

- 폴더가 아직 없거나 읽지 못한 상태에서는 위젯 안에 경로 입력칸이 나옵니다.
  `~/Documents`, `$HOME/Documents`, `/home/user/notes` 모두 됩니다(`~`는 셸이 확장).
- 문서를 보는 중에 폴더를 바꾸려면 헤더의 **⚙ 버튼**을 누르세요.
  경로 · 정렬 · 글자 크기를 위젯 안에서 바로 바꿀 수 있습니다.
- 잘못된 경로를 넣어도 목록이 비어 있는 한 입력칸이 계속 남아 있어 다시 넣을 수 있습니다.
- 문서를 보는 중이면 헤더의 **⚙** 버튼으로 같은 항목을 엽니다.

## 터미널에서 폴더 열기

우클릭 메뉴에서 현재 Markdown 폴더를 **KDE에 설정된 기본 터미널**로 엽니다.
탐색은 `contents/scripts/open-terminal.sh`가 담당하며, 순서는 다음과 같습니다.

1. `kdeglobals [General] TerminalApplication` — 시스템 설정 → 기본 프로그램 → 터미널의 Exec 라인
   (예: `wezterm`)
2. `kdeglobals [General] TerminalService` — 데스크톱 파일 ID(`org.wezfurlong.wezterm.desktop`)
   에서 `Exec=`를 읽어 실행
3. `xdg-terminal-exec` → `konsole` → `x-terminal-emulator`

터미널은 **대상 폴더를 현재 디렉터리로** 하고 실행되므로, 셸이 그 경로에서 시작합니다.
셋 다 없으면 위젯 상단에 "터미널을 열지 못했습니다."가 표시됩니다.

> KDE 설정 키는 `kcms/componentchooser/terminal_settings.kcfg`(plasma-workspace 6.8.2)에 정의된
> `kdeglobals [General] TerminalApplication/TerminalService`입니다.

## 알려진 문제: 설정 대화상자가 비어 보임

KDE 위젯 설정 대화상자에서 카테고리 페이지를 열 때 Plasma 내부에서 오류가 납니다.

```
PageRow.qml:1000: TypeError: Passing incompatible arguments to C++ functions from JavaScript is not allowed.
  "initAndInsertPage@.../PageRow.qml:1000"
  "insertPage_unchecked@.../PageRow.qml:945"
  "push@.../PageRow.qml:241"
  "pushReplace@.../AppletConfiguration.qml:111"
  "openCategory@.../AppletConfiguration.qml:296"
```

페이지 삽입 단계(`AppletConfiguration.qml` → `PageRow.push`)에서 실패하므로 위젯 쪽 QML을
어떻게 고쳐도 이 대화상자는 비어 있습니다. 디지털 시계 등 **다른 위젯의 설정도 비어 있다면
Plasma/Kirigami 쪽 문제**이므로, 이 패키지는 설정 UI를 위젯 내부로 옮겼습니다.

## 패널에 넣기

- 패널에 추가하면 **아이콘 하나 크기**로 접힙니다(메모지 위젯과 같은 방식).
- 아이콘을 클릭하면 팝업으로 리더가 열리고, 바깥을 클릭하면 닫힙니다.
- 아이콘에 마우스를 올리면 현재 파일명이 툴팁으로 나옵니다.
- 설정은 팝업 안에서: 본문 경로 입력칸 또는 헤더 ⚙.

## 사용

| 동작                   | 방법                                                   |
| ---------------------- | ------------------------------------------------------ |
| 다음 문서              | `→` 키, 헤더의 `>` 버튼                                |
| 이전 문서              | `←` 키, 헤더의 `<` 버튼                                |
| 처음/마지막에서        | 순환합니다 (마지막 다음은 처음)                        |
| 긴 문서 스크롤         | `↑` `↓` 키(약 3줄씩) / 마우스 휠 / 스크롤바 / 드래그   |
| 목록 갱신              | 헤더의 새로 고침 버튼, 또는 15초마다 자동              |
| 폴더를 터미널에서 열기 | 위젯 우클릭 → 컨텍스트 메뉴 → "폴더를 터미널에서 열기" |

원본 파일의 **줄바꿈을 그대로** 표시합니다. Markdown 표준은 줄바꿈 하나를 공백으로 합치지만,
이 위젯은 코드 블록 밖의 각 줄 끝에 하드 브레이크(공백 2칸)를 붙여 줄 구조를 유지합니다.
빈 줄은 문단을 끊는 동시에, 한 줄 높이의 여백 문단(NBSP)으로 바꿔 넣습니다.
(Qt의 Markdown 변환은 문단 여백을 `pointSize * 2/3`로 잡는데, 이 값이 0이 되면 빈 줄이
화면에서 사라지기 때문입니다.)

폴더 안의 `*.md`, `*.markdown` 파일을 이름순(또는 수정시각순)으로 정렬합니다.
하위 폴더는 들어가지 않습니다(`-maxdepth 1`).

## 구조

```
markdownreader/
├── metadata.json                  # KPackage 메타데이터 (Plasma/Applet)
└── contents/
    └── config/main.xml            # 설정 항목 (folderPath, sortBy, fontSize)
    └── ui/main.qml                # 위젯 본체
```

## 동작 방식

- 폴더 목록은 `plasma5support`의 **executable** 데이터엔진으로 `find`를 한 번 실행해 얻습니다.
  이 엔진은 `KProcess::setShellCommand()`로 `/bin/sh -c`를 쓰기 때문에 파이프·따옴표가 그대로 동작하고,
  결과는 `stdout` 문자열 하나로 돌아옵니다.
- 문서 본문은 `cat -- '<경로>'` 한 번으로 읽고, 경로별로 캐시합니다.
- 렌더링은 Qt Quick `TextEdit`의 `MarkdownText` 모드입니다.
  (`QQuickTextEdit`는 `QTextDocument::setMarkdown`으로 그립니다.)

참고 소스:

- plasma5support executable 엔진: <https://github.com/KDE/plasma5support/blob/master/src/dataengines/executable/executable.cpp>
- QML 모듈 URI `org.kde.plasma.plasma5support`: <https://github.com/KDE/plasma5support/blob/master/src/declarativeimports/CMakeLists.txt>
- Qt `TextEdit`의 markdown 경로: <https://github.com/qt/qtdeclarative/blob/6.9/src/quick/items/qquicktextedit.cpp>
- (설정 KCM 페이지는 Plasma 쪽 페이지 삽입 오류 때문에 `attic/`으로 옮겨 두었습니다)

## 한계

- Qt의 Markdown 렌더링은 CommonMark 계열 **서브셋**입니다. 표·각주·인라인 HTML·체크박스 등은
  그대로 or 제한적으로 보일 수 있습니다.
- 상대 경로 이미지는 표시되지 않을 수 있습니다(문서 기준 경로 해석 불가).
- 파일이 아주 크면(수 MB) 렌더링이 느려집니다.
- 편집·저장, 검색, 목차 이동은 지원하지 않습니다.

## 문제 해결

증상이 있으면 터미널에서 plasmashell 로그를 보면서 확인합니다.

```bash
# 1) 목록 명령이 실제로 뭐를 돌려주는지
find "$HOME/notes" -maxdepth 1 -type f \( -iname '*.md' -o -iname '*.markdown' \) -printf '%T@\t%p\n'

# 2) 위젯 로딩 오류 확인
kquitapp6 plasmashell && kstart plasmashell 2>&1 | tail -50
journalctl --user -b -u plasma-plasmashell -n 100 --no-pager
```

설정 페이지가 **비어 보이면** QML 로딩이 실패한 것입니다. plasmashell을 터미널에서 띄워 오류 줄을 확인합니다.

```bash
journalctl --user -b -o cat | grep -iE 'PageRow|AppletConfiguration|markdownreader' | tail -20
```

QML 오류가 나오면 그 메시지를 그대로 알려주시면 바로 고치겠습니다.

## Attribution

- **작성자 / 관리자:** [nemonein](https://github.com/nemonein)
- **AI 지원:** DeepSeek (모델 `deepseek-flash`) — 초기 QML 구현, Markdown 렌더링·키보드
  포커스·패널 동작 반복 개선, 설치 스크립트와 터미널 실행 스크립트 작성에 사용.

AI가 함께 작성한 커밋은 이력에 `Co-authored-by` trailer로 표시합니다.

```
Co-authored-by: DeepSeek <noreply@deepseek.com>
```

DeepSeek는 이 프로젝트에 연결된 공개 GitHub 계정이 없어, GitHub UI에서는 프로필 링크가
아닌 공동 작성자 텍스트로만 표시됩니다. 모든 변경은 관리자가 검토·실행·테스트하며,
코드와 라이선스에 대한 책임은 관리자에게 있습니다.

## 제거

```bash
kpackagetool6 --type Plasma/Applet --remove com.github.plasma-markdownreader
```
