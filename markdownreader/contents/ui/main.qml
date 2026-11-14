/*
    SPDX-FileCopyrightText: 2026 박정
    SPDX-License-Identifier: MIT

    Markdown Reader — Plasma 6 applet
    지정한 폴더의 Markdown 파일을 한 번에 하나씩, 읽기 전용으로 넘겨 봅니다.
*/

import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    implicitWidth: root.isInPanel ? Kirigami.Units.iconSizes.large : Kirigami.Units.gridUnit * 26
    implicitHeight: root.isInPanel ? Kirigami.Units.iconSizes.large : Kirigami.Units.gridUnit * 22

    // 패널에서는 배경 없이 아이콘만, 데스크톱에서는 기본 배경
    readonly property bool isInPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
        || Plasmoid.formFactor === PlasmaCore.Types.Vertical
    Plasmoid.backgroundHints: root.isInPanel
        ? PlasmaCore.Types.NoBackground
        : PlasmaCore.Types.DefaultBackground

    // 우클릭 컨텍스트 메뉴 항목
    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: root.tr("폴더를 터미널에서 열기", "Open folder in terminal")
            icon.name: "utilities-terminal"
            visible: root.folderPath.length > 0
            onTriggered: root.openInTerminal()
        }
    ]

    // 패널에서 아이콘 하나로 접히고, 클릭하면 팝업으로 펼쳐집니다.
    switchWidth: Kirigami.Units.gridUnit * 10
    switchHeight: Kirigami.Units.gridUnit * 6

    Layout.minimumWidth: root.isInPanel ? Kirigami.Units.iconSizes.medium : Kirigami.Units.gridUnit * 12
    Layout.minimumHeight: root.isInPanel ? Kirigami.Units.iconSizes.medium : Kirigami.Units.gridUnit * 8
    Layout.preferredWidth: root.isInPanel ? Kirigami.Units.iconSizes.large : Kirigami.Units.gridUnit * 26
    Layout.preferredHeight: root.isInPanel ? Kirigami.Units.iconSizes.large : Kirigami.Units.gridUnit * 22

    // 현재 로케일이 한국어면 한국어, 그 외에는 영어로 표시합니다.
    readonly property bool isKorean: String(Qt.locale().name).toLowerCase().indexOf("ko") === 0

    function tr(ko, en) {
        return root.isKorean ? ko : en;
    }

    readonly property string folderPath: String(Plasmoid.configuration.folderPath || "")
    readonly property int fontPointSize: Number(Plasmoid.configuration.fontSize) || 0
    // 설정 값이 0이면 테마 기본 글꼴을 씁니다. 설정 패널에는 이 "실제 크기"를 보여 줍니다.
    readonly property int effectivePointSize: root.fontPointSize > 0 ? root.fontPointSize : root.themePointSize()
    readonly property string currentFileName: root.currentFile.length > 0
        ? root.currentFile.slice(root.currentFile.lastIndexOf("/") + 1)
        : ""

    // 문서 목록 / 현재 문서 상태
    property var files: []
    property int currentIndex: -1
    property string currentFile: ""
    property string documentText: ""
    property string statusMessage: ""
    property string resumeFile: ""
    property bool settingsOpen: false
    property var cache: ({})
    property var fileMtime: ({})
    property var pending: ({})

    onFolderPathChanged: reloadList(false)

    onExpandedChanged: {
        if (!root.expanded) {
            return;
        }
        // 팝업 창이 활성화되기까지 약간 시간이 걸리므로 지연 후 포커스를 잡습니다.
        focusTimer.restart();
    }

    Timer {
        id: focusTimer
        interval: 150
        repeat: false
        onTriggered: {
            try {
                editor.forceActiveFocus();
            } catch (e) {
                // 뷰가 아직 생성되지 않은 경우 무시
            }
        }
    }

    // Qt의 Markdown 렌더링은 CommonMark 규칙이라 줄바꿈 하나는 공백으로 합쳐집니다.
    // 원본 파일의 줄 구조를 그대로 보여 주기 위해, 코드 블록 밖의 각 줄 끝에
    // 공백 2칸(하드 브레이크)을 붙입니다.
    function mdForDisplay(text) {
        const lines = String(text).replace(/\r\n/g, "\n").split("\n");
        let inFence = false;
        const out = [];
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (/^\s*(```|~~~)/.test(line)) {
                inFence = !inFence;
                out.push(line);
                continue;
            }
            if (inFence) {
                out.push(line);
                continue;
            }
            if (line.trim().length === 0) {
                // 빈 줄: 문단을 끊고, 눈에 보이는 한 줄 높이의 여백을 따로 넣습니다.
                // (Qt가 문단 여백을 0으로 잡는 경우에도 빈 줄이 사라지지 않도록)
                out.push("");
                if (i < lines.length - 1) {
                    // 여백 줄도 하드 브레이크로 끝내야 다음 줄과 한 줄로 합쳐지지 않습니다.
                    out.push("\u00A0  ");
                }
                continue;
            }
            out.push(line.replace(/\s+$/, "") + "  ");
        }
        return out.join("\n");
    }

    // 위/아래 키로 문서를 스크롤합니다 (약 3줄씩).
    // file:// URL → 로컬 경로
    function localPath(url) {
        let p = String(url);
        if (p.indexOf("file://") === 0) {
            p = decodeURIComponent(p.slice("file://".length));
        }
        return p;
    }

    // 현재 폴더를 KDE 기본 터미널에서 엽니다.
    // 실제 터미널 탐색은 contents/scripts/open-terminal.sh 가 담당합니다.
    function openInTerminal() {
        if (root.folderPath.length === 0) {
            return;
        }
        const helper = localPath(Qt.resolvedUrl("../scripts/open-terminal.sh"));
        const command = "sh " + shq(helper) + " " + shellPath(root.folderPath);
        root.pending[command] = { kind: "terminal" };
        execEngine.connectSource(command);
    }

    function resetScroll() {
        try {
            flickable.contentY = 0;
        } catch (e) {
            // 뷰가 아직 생성되지 않은 경우 무시
        }
    }

    function themePointSize() {
        const size = Kirigami.Theme.defaultFont.pointSize;
        return size > 0 ? size : 10;
    }

    Component.onCompleted: reloadList(false)

    // 셸 인자 하나를 안전하게 인용합니다 ('...' 형태, 내부 따옴표는 '\''로 이스케이프)
    function shq(value) {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    // "~" 또는 "$HOME"으로 시작하는 경로는 셸이 확장하도록 넘깁니다.
    // (single-quote로 감싸면 ~가 문자 그대로 남아 find가 실패합니다)
    function shellPath(value) {
        const raw = String(value).trim();
        if (raw === "~" || raw === "$HOME") {
            return "\"$HOME\"";
        }
        if (raw.indexOf("~/") === 0) {
            return "\"$HOME\"/" + shq(raw.slice(2));
        }
        if (raw.indexOf("$HOME/") === 0) {
            return "\"$HOME\"/" + shq(raw.slice(6));
        }
        return shq(raw);
    }

    function reloadList(keepPosition) {
        root.resumeFile = keepPosition ? root.currentFile : "";
        if (!keepPosition) {
            root.currentFile = "";
            root.currentIndex = -1;
            root.documentText = "";
            root.cache = ({});
            root.fileMtime = ({});
            root.files = [];
            root.statusMessage = root.tr("불러오는 중…", "Loading…");
        }
        root.pending = ({});

        if (root.folderPath.length === 0) {
            root.statusMessage = root.tr("위젯 설정에서 Markdown 폴더를 선택하세요.", "Choose a Markdown folder in the widget settings.");
            return;
        }

        const command = "find " + shellPath(root.folderPath)
            + " -maxdepth 1 -type f \\( -iname '*.md' -o -iname '*.markdown' \\)"
            + " -printf '%T@\\t%p\\n'";
        root.pending[command] = { kind: "list" };
        execEngine.connectSource(command);
    }

    function handleList(stdout, stderr, exitCode) {
        if (exitCode !== 0) {
            root.statusMessage = root.tr("폴더를 읽지 못했습니다.", "Could not read the folder.") + " " + stderr.trim();
            return;
        }

        const entries = [];
        const lines = stdout.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (line.length === 0) {
                continue;
            }
            const tab = line.indexOf("\t");
            const mtime = tab > 0 ? Number(line.slice(0, tab)) : 0;
            const path = tab > 0 ? line.slice(tab + 1) : line;
            entries.push({ path: path, mtime: mtime, name: path.slice(path.lastIndexOf("/") + 1) });
        }

        const sortBy = String(Plasmoid.configuration.sortBy || "name");
        entries.sort(function (a, b) {
            return sortBy === "mtime" ? b.mtime - a.mtime : a.name.localeCompare(b.name);
        });

        const newFiles = entries.map(function (entry) { return entry.path; });
        const newMtimes = ({});
        for (let i = 0; i < entries.length; i++) {
            newMtimes[entries[i].path] = entries[i].mtime;
        }

        if (newFiles.length === 0) {
            root.files = newFiles;
            root.fileMtime = newMtimes;
            root.statusMessage = root.tr("이 폴더에 Markdown 파일이 없습니다.", "No Markdown files in this folder.");
            return;
        }

        // 자동 갱신에서 읽던 파일이 그대로면 다시 읽지 않습니다.
        // (텍스트를 다시 넣으면 TextEdit 스크롤이 맨 위로 돌아갑니다.)
        if (root.resumeFile.length > 0 && root.currentFile === root.resumeFile) {
            const found = newFiles.indexOf(root.resumeFile);
            const oldTime = root.fileMtime[root.resumeFile];
            if (found >= 0 && oldTime !== undefined && oldTime === newMtimes[root.resumeFile]) {
                root.files = newFiles;
                root.fileMtime = newMtimes;
                root.currentIndex = found;
                root.statusMessage = "";
                return;
            }
            if (found >= 0) {
                // 내용이 바뀐 경우에만 그 문서를 다시 읽습니다.
                root.cache[root.resumeFile] = undefined;
            }
        }

        root.files = newFiles;
        root.fileMtime = newMtimes;
        root.statusMessage = "";
        let wanted = 0;
        if (root.resumeFile.length > 0) {
            const foundIndex = newFiles.indexOf(root.resumeFile);
            if (foundIndex >= 0) {
                wanted = foundIndex;
            }
        }
        showFile(wanted);
    }

    function handleContent(path, stdout, stderr, exitCode) {
        if (path !== root.currentFile) {
            return; // 이미 다른 문서로 넘어간 뒤 도착한 응답
        }
        if (exitCode !== 0) {
            root.documentText = "";
            root.statusMessage = root.tr("파일을 읽지 못했습니다.", "Could not read the file.") + " " + stderr.trim();
            return;
        }
        root.cache[path] = stdout;
        root.documentText = mdForDisplay(stdout);
        root.statusMessage = "";
    }

    function showFile(index) {
        const count = root.files.length;
        if (count === 0) {
            return;
        }
        root.currentIndex = ((index % count) + count) % count;
        const path = root.files[root.currentIndex];
        root.currentFile = path;
        resetScroll();

        if (root.cache[path] !== undefined) {
            root.documentText = mdForDisplay(root.cache[path]);
            root.statusMessage = "";
            return;
        }

        root.documentText = "";
        root.statusMessage = root.tr("불러오는 중…", "Loading…");
        const command = "cat -- " + shq(path);
        root.pending[command] = { kind: "read", path: path };
        execEngine.connectSource(command);
    }

    function previous() {
        if (root.files.length > 1) {
            showFile(root.currentIndex - 1);
        }
    }

    function next() {
        if (root.files.length > 1) {
            showFile(root.currentIndex + 1);
        }
    }

    // 설정 대화상자를 열지 않고도 폴더를 지정할 수 있게 합니다.
    function applyPath(text) {
        const value = String(text).trim();
        if (value.length > 0) {
            Plasmoid.configuration.folderPath = value;
        }
    }

    // 셸 명령 실행 (plasma5support의 executable 엔진은 /bin/sh -c 로 실행됩니다)
    P5Support.DataSource {
        id: execEngine
        engine: "executable"
        connectedSources: []

        onNewData: function (sourceName, data) {
            execEngine.disconnectSource(sourceName);

            const job = root.pending[sourceName];
            root.pending[sourceName] = undefined;
            if (job === undefined) {
                return;
            }

            const stdout = String(data["stdout"] === undefined ? "" : data["stdout"]);
            const stderr = String(data["stderr"] === undefined ? "" : data["stderr"]);
            const exitCode = data["exit code"] === undefined ? 0 : Number(data["exit code"]);

            if (job.kind === "list") {
                handleList(stdout, stderr, exitCode);
            } else if (job.kind === "read") {
                handleContent(job.path, stdout, stderr, exitCode);
            } else if (job.kind === "terminal" && exitCode !== 0) {
                root.statusMessage = root.tr("터미널을 열지 못했습니다.", "Could not open a terminal.") + " " + stderr.trim();
            }
        }
    }

    // 파일이 추가/수정되면 15초마다 목록을 갱신합니다.
    Timer {
        interval: 15000
        repeat: true
        running: root.visible && root.folderPath.length > 0
        onTriggered: root.reloadList(true)
    }

    compactRepresentation: MouseArea {
        id: compactRoot
        // 패널 두께에 맞춰 커지고, 48px에서 상한 (패널이 더 얇으면 패널이 제한)
        implicitWidth: Kirigami.Units.iconSizes.large
        implicitHeight: Kirigami.Units.iconSizes.large
        Layout.preferredWidth: Kirigami.Units.iconSizes.large
        Layout.preferredHeight: Kirigami.Units.iconSizes.large
        Layout.maximumWidth: Kirigami.Units.iconSizes.large
        Layout.maximumHeight: Kirigami.Units.iconSizes.large
        Layout.minimumWidth: Kirigami.Units.iconSizes.medium
        Layout.minimumHeight: Kirigami.Units.iconSizes.medium
        onClicked: root.expanded = !root.expanded

        // 패키지에 포함한 markdown.svg를 테마 전경색 마스크로 그립니다.
        Kirigami.Icon {
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height)
            height: width
            source: Qt.resolvedUrl("../icons/markdown.svg")
            isMask: true
            color: Kirigami.Theme.textColor
            roundToIconSize: false
        }
    }

    fullRepresentation: ColumnLayout {
        id: fullRoot

        Layout.minimumWidth: Kirigami.Units.gridUnit * 14
        Layout.minimumHeight: Kirigami.Units.gridUnit * 8
        Layout.preferredWidth: Kirigami.Units.gridUnit * 26
        Layout.preferredHeight: Kirigami.Units.gridUnit * 22
        implicitWidth: Kirigami.Units.gridUnit * 26
        implicitHeight: Kirigami.Units.gridUnit * 22
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            Layout.bottomMargin: 0
            spacing: Kirigami.Units.smallSpacing
            visible: root.files.length > 0

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                QQC2.Label {
                    Layout.fillWidth: true
                    text: root.currentFileName
                    elide: Text.ElideMiddle
                    font.weight: Font.DemiBold
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    text: root.currentIndex >= 0
                        ? (root.currentIndex + 1) + " / " + root.files.length
                        : ""
                    opacity: 0.7
                    font: Kirigami.Theme.smallFont
                }
            }

            QQC2.ToolButton {
                icon.name: "configure"
                focusPolicy: Qt.NoFocus
                onClicked: root.settingsOpen = !root.settingsOpen

                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: root.tr("폴더 / 정렬 / 글자 크기", "Folder / sort / font size")
            }

            QQC2.ToolButton {
                icon.name: "view-refresh"
                focusPolicy: Qt.NoFocus
                onClicked: root.reloadList(true)

                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: root.tr("새로 고침", "Reload")
            }

            QQC2.ToolButton {
                icon.name: "go-previous"
                enabled: root.files.length > 1
                focusPolicy: Qt.NoFocus
                onClicked: root.previous()

                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: root.tr("이전 문서 (←)", "Previous document (←)")
            }

            QQC2.ToolButton {
                icon.name: "go-next"
                enabled: root.files.length > 1
                focusPolicy: Qt.NoFocus
                onClicked: root.next()

                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: root.tr("다음 문서 (→)", "Next document (→)")
            }
        }

        // 헤더의 ⚙ 로 여는 위젯 내 설정 (설정 대화상자와 같은 값을 씁니다)
        Rectangle {
            id: settingsPanel
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            Layout.preferredHeight: settingsColumn.implicitHeight + Kirigami.Units.smallSpacing * 2
            visible: root.settingsOpen && root.files.length > 0
            color: Kirigami.Theme.alternateBackgroundColor
            radius: Kirigami.Units.smallSpacing
            border.width: 1
            border.color: Kirigami.Theme.disabledTextColor

            ColumnLayout {
                id: settingsColumn
                x: Kirigami.Units.smallSpacing
                y: Kirigami.Units.smallSpacing
                width: parent.width - Kirigami.Units.smallSpacing * 2
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.TextField {
                        id: settingsPathField
                        Layout.fillWidth: true
                        text: root.folderPath
                        placeholderText: root.tr("Markdown 폴더 (예: ~/Documents)", "Markdown folder (e.g. ~/Documents)")
                        onAccepted: root.applyPath(settingsPathField.text)
                    }

                    QQC2.Button {
                        text: root.tr("열기", "Open")
                        onClicked: root.applyPath(settingsPathField.text)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        text: root.tr("정렬:", "Sort:")
                    }

                    QQC2.ComboBox {
                        model: [ root.tr("파일 이름", "File name"), root.tr("수정한 시각", "Modified time") ]
                        currentIndex: Plasmoid.configuration.sortBy === "mtime" ? 1 : 0
                        onActivated: {
                            Plasmoid.configuration.sortBy = (index === 1 ? "mtime" : "name");
                            root.reloadList(true);
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    QQC2.Label {
                        text: root.tr("글자:", "Size:")
                    }

                    QQC2.SpinBox {
                        from: 6
                        to: 40
                        stepSize: 1
                        value: root.effectivePointSize
                        textFromValue: function (value) { return value + " pt"; }
                        valueFromText: function (text) { return parseInt(text) || root.effectivePointSize; }
                        onValueModified: Plasmoid.configuration.fontSize = value
                    }
                }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.smallSpacing
            Layout.rightMargin: Kirigami.Units.smallSpacing
            visible: root.files.length > 0 && root.statusMessage.length > 0
            text: root.statusMessage
            color: Kirigami.Theme.negativeTextColor
            elide: Text.ElideRight
            font: Kirigami.Theme.smallFont
        }

        Flickable {
            id: flickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.files.length > 0
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            contentWidth: width
            contentHeight: editor.contentHeight + Kirigami.Units.smallSpacing * 2

            QQC2.ScrollBar.vertical: QQC2.ScrollBar { }

            TextEdit {
                id: editor
                x: Kirigami.Units.smallSpacing
                y: Kirigami.Units.smallSpacing
                width: flickable.width - Kirigami.Units.smallSpacing * 2
                height: contentHeight
                text: root.documentText
                textFormat: TextEdit.MarkdownText
                wrapMode: TextEdit.Wrap
                readOnly: true
                selectByMouse: true
                focus: true
                activeFocusOnTab: false
                cursorVisible: false
                color: Kirigami.Theme.textColor
                font: root.fontPointSize > 0
                    ? Qt.font({ pointSize: root.fontPointSize })
                    : Kirigami.Theme.defaultFont

                // 좌우: 문서 이동, 상하: 스크롤.
                // TextEdit이 방향키를 커서 이동으로 처리하지 못하도록 catch-all에서 accepted를 지정합니다.
                // 팝업 창이 활성화되는 순간 포커스를 잡아, 클릭 없이도 키가 먹게 합니다.
                Connections {
                    target: editor.Window.window

                    function onActiveChanged() {
                        const win = editor.Window.window;
                        if (win !== null && win.active) {
                            editor.forceActiveFocus();
                        }
                    }
                }

                Component.onCompleted: focusTimer.restart()

                Keys.onPressed: function (event) {
                    const step = Math.max(40, Math.round(root.effectivePointSize * 4));
                    if (event.key === Qt.Key_Left) {
                        event.accepted = true;
                        root.previous();
                    } else if (event.key === Qt.Key_Right) {
                        event.accepted = true;
                        root.next();
                    } else if (event.key === Qt.Key_Up) {
                        event.accepted = true;
                        flickable.contentY = Math.max(0, flickable.contentY - step);
                    } else if (event.key === Qt.Key_Down) {
                        event.accepted = true;
                        const maxY = Math.max(0, flickable.contentHeight - flickable.height);
                        flickable.contentY = Math.min(maxY, flickable.contentY + step);
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.files.length === 0

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - Kirigami.Units.largeSpacing * 2,
                                Kirigami.Units.gridUnit * 18)
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                    Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                    source: Qt.resolvedUrl("../icons/markdown.svg")
                    isMask: true
                    color: Kirigami.Theme.textColor
                    opacity: 0.5
                }

                QQC2.Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: root.statusMessage
                    opacity: 0.8
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.TextField {
                        id: pathField
                        Layout.fillWidth: true
                        text: root.folderPath
                        placeholderText: root.tr("Markdown 폴더 (예: ~/Documents)", "Markdown folder (e.g. ~/Documents)")
                        onAccepted: root.applyPath(pathField.text)
                    }

                    QQC2.Button {
                        text: root.tr("열기", "Open")
                        enabled: pathField.text.trim().length > 0
                        onClicked: root.applyPath(pathField.text)
                    }
                }
            }
        }
    }
}
