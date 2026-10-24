// ModelSelect.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root



    // ---------- Public API ----------
    property bool locked: false
    property bool available: true

    property string cur_provider: "" // idx of provider,in @modelGroups
    // Status: "idle", "loading", "ready", "selecting", "error"
    property string status: "idle"
    property string errorMessage: ""
    // Array of failures: { id, name, message }
    property var groupFailures: []

    // Signals to request data operations from host
    signal selectionRequested()
    signal get_provider_idx()

    // ---------- Internal State ----------
    property bool open: false
    property string pane: "root"     // "root", "model", "effort"
    property string lastAction: "load"
    property bool toastVisible: false
    property string toastText: ""

    // Derived data
    //property var choices: []        // flattened model options: { group, model, selection }
    property var cur_models: null
    property var cur_efforts: null
    property string cur_model: ""
    property string cur_effort: ""
    signal model_change()
    signal effort_change()

    //onCur_modelsChanged: console.log("cur_models:",cur_models,"\n")

    // Focus management
    property var focusItems: []     // array of QML items that are focusable in current pane
    property int currentFocusIndex: -1

    // ---------- Actions ----------
    //no exposed
    function showMenu() {
        open = true
        pane = "root"
        lastAction = "load"
        // Collect focus items after pane set
        collectFocusItems()
        setInitialFocus()
    }

    //no exposed
    function closeMenu(restoreFocus) {
        open = false
        pane = "root"
        if (restoreFocus) {
            triggerButton.forceActiveFocus()
        }
    }

    function reload() {
        lastAction = "load"
        store_models_efforts_from_provider()
    }

    //no exposed
    function change_efforts_by_model() {
        for (var i=0;i<cur_models.length;i++) {
            if(cur_models[i].name===cur_model){
                cur_efforts=cur_models[i].efforts
            }
        }
        //error
    }

    //no exposed
    function chooseModel(model_name) {
        if (cur_model === model_name) {
            closeMenu(true)
            return
        }
        lastAction = "select"
        cur_model=model_name
        change_efforts_by_model()
        if(cur_effort!=="") chooseEffort(cur_effort)
        //signal
        model_change()
    }

    //no exposed
    function chooseEffort(effort_name) {
        for(var i=0;i<cur_efforts.length;i++){
            if(cur_efforts[i].name===effort_name){
                //call in chooseModel
                if(cur_effort===effort_name) return
                cur_effort=effort_name
                break
            }
        }
        lastAction = "select"
        //signal
        effort_change()
    }

    //这个函数到底还有没有用，忘了
    // ---------- Focus Management ----------
    function collectFocusItems() {
        focusItems = []
        if (!open) return

        if (pane === "root") {
            focusItems.push(modelRowButton)
            //if (reasoning) focusItems.push(effortRowButton)
            if (cur_efforts) focusItems.push(effortRowButton)
        } else if (pane === "model") {
            // Collect all model option buttons from the list
            // We use a helper to traverse the model list's contentItem
            for (var i = 0; i < modelListView.count; i++) {
                var item = modelListView.itemAtIndex(i)
                if (item && item.focusable) {
                    focusItems.push(item)
                }
            }
        } else if (pane === "effort") {
            for (var j = 0; j < effortListView.count; j++) {
                var effItem = effortListView.itemAtIndex(j)
                if (effItem && effItem.focusable) {
                    focusItems.push(effItem)
                }
            }
        }
    }

    function setInitialFocus() {
        if (focusItems.length > 0) {
            currentFocusIndex = 0
            focusItems[0].forceActiveFocus()
        }
    }

    function moveFocus(offset) {
        if (focusItems.length === 0) {
            collectFocusItems()
        }
        if (focusItems.length === 0) return

        // Determine currently focused item
        var activeIdx = -1
        for (var i = 0; i < focusItems.length; i++) {
            if (focusItems[i].activeFocus) {
                activeIdx = i
                break
            }
        }
        if (activeIdx === -1) {
            // No focus, set to first
            activeIdx = 0
        } else {
            activeIdx = (activeIdx + offset + focusItems.length) % focusItems.length
        }
        currentFocusIndex = activeIdx
        focusItems[activeIdx].forceActiveFocus()
    }

    // 自定义翻译
    function t(key, params) {
        var map = {
            "trigger.fallback": "选择模型",
            "menu.model": "模型 ",
            "menu.effort": "推理强度 ",
            "effort.providerDefault": "提供方默认",
            "status.loading": "加载中...",
            "empty.models": "无可用模型",
            "empty.efforts": "无可用强度"
        }
        var text = map[key] || key
        return text.replace(/%(\d+)/g, function(m, idx) {
            return params["%" + idx] || m
        })
            }

    // Called when pane changes
    onPaneChanged: {
        if (open) {
            collectFocusItems()
            setInitialFocus()
        }
    }

    // ---------- Keyboard Handling ----------
    Keys.onEscapePressed: {
        if (open) {
            if (pane !== "root") {
                pane = "root"
            } else {
                closeMenu(true)
            }
            event.accepted = true
        }
    }
    Keys.onUpPressed: {
        if (open) {
            moveFocus(-1)
            event.accepted = true
        }
    }
    Keys.onDownPressed: {
        if (open) {
            moveFocus(1)
            event.accepted = true
        }
    }
    // Forward key events to menu popup for proper handling
    Keys.forwardTo: [menuPopup]

    // ---------- UI ----------
    width: triggerButton.width
    //height: triggerButton.height

    //implicitWidth: triggerButton.width

    // Trigger Button
    Button {
        id: triggerButton
        //anchors.fill: parent

        //implicitWidth: modelRowButton.width + effortRowButton.width + 5

        background: Rectangle {
            // 浅色专业风格配色
            border.width: 1
            radius: 16
            clip: true
            color: triggerButton.hovered ? "#c0c0c0" : "#ffffff"
        }

        enabled: !locked
        onClicked: {
            if (open) {
                closeMenu(true)
            } else {
                showMenu()
            }
        }

        contentItem: RowLayout {
            id:selected_me
            anchors.fill: parent
            spacing: 4
            Text {
                id: modelNameText
                text: resolve_text()
                //elide: Text.ElideRight
                Layout.alignment: Qt.AlignHCenter

                function resolve_text() {
                    if(cur_provider==="") return "add provider first"
                    if(cur_model==="") return "select model"
                    return cur_model
                }
            }
            Text {
                id: effortText
                visible: cur_effort !== ""
                text: cur_effort
                styleColor: "#000000"

                Layout.rightMargin: 3
            }
        }
    }

    // Popup Menu
    Popup {
        id: menuPopup

        x: triggerButton.x
        y: triggerButton.y - height
        width: Math.max(triggerButton.width, 260)
        visible: root.open
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onClosed: {
            parent.open = false
            pane = "root"
        }

        contentItem: Rectangle {
            anchors.fill: parent

            ColumnLayout {
                id: menuColumn
                anchors.fill: parent
                spacing: 0

                // Root pane
                Item {
                    id: item1
                    visible: pane === "root"
                    Layout.fillWidth: true
                    implicitHeight: rootPaneColumn.height
                    width: Math.max(effortRowButton.width,modelRowButton.width)

                    Column {
                        id: rootPaneColumn
                        // anchors.left: parent.left
                        // anchors.right: parent.right
                        // Model row
                        Button {
                            id: modelRowButton

                            //width: Math.max(effortRowButton.width,width)


                            background: Rectangle {
                                // 浅色专业风格配色
                                border.width: 1
                                radius: 16
                                clip: true
                                color: modelRowButton.hovered ? "#c0c0c0" : "#ffffff"
                            }

                            onClicked: {
                                pane = "model"
                                //console.log("cur_models :",cur_models.length)
                            }

                            //Accessible.role: Accessible.MenuItem
                            focus: true
                            contentItem: RowLayout {
                                id:c_row
                                Text { text: "模型 "; Layout.fillWidth: true }
                                Text { text: cur_model; color: palette.mid }
                                Text { text: "›" }
                            }
                        }
                        // Effort row (only if reasoning available)
                        Button {
                            id: effortRowButton

                            background: Rectangle {
                                // 浅色专业风格配色
                                //border.color: "#E5E7EB"
                                border.width: 1
                                radius: 16
                                clip: true
                                color: effortRowButton.hovered ? "#c0c0c0" : "#ffffff"
                            }


                            onClicked: pane = "effort"
                            //Accessible.role: Accessible.MenuItem
                            focus: true
                            property string effort_name: ""
                            contentItem: RowLayout {
                                Text { text: "推理强度"; Layout.fillWidth: true }
                                Text { text: cur_effort; color: palette.mid }
                                Text { text: "›" }
                            }
                        }
                    }
                }

                // Model pane
                Rectangle {
                    visible: pane === "model"
                    Layout.fillWidth: true
                    implicitHeight: modelPaneColumn.height

                    // 浅色专业风格配色
                    border.width: 1
                    radius: 10
                    clip: true
                    color: modelRowButton.hovered ? "#c0c0c0" : "#ffffff"

                    ColumnLayout {
                        id: modelPaneColumn
                        width: parent.width

                        Text {
                            text: cur_provider
                            font.pointSize: 7
                            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                        }

                        ListView {
                            id: modelListView
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(contentHeight, 300)
                            clip: true

                            boundsBehavior: Flickable.StopAtBounds

                            model: root.cur_models

                            delegate: Button {
                                id: model_list_item
                                background: Rectangle {
                                    // 浅色专业风格配色
                                    //border.color: "#E5E7EB"
                                    border.width: 1
                                    radius: 16
                                    clip: true
                                    color: model_list_item.hovered ? "#c0c0c0" : "#ffffff"
                                }

                                width: modelListView.width
                                enabled: status !== "selecting"
                                onClicked: {
                                    chooseModel(modelData.name)
                                    root.pane="root"
                                }

                                focus: true
                                contentItem: RowLayout {
                                    ColumnLayout {
                                        Layout.alignment: Qt.AlignLeft
                                        Layout.fillWidth: true
                                        Text { text: modelData.name; elide: Text.ElideRight }
                                    }
                                }
                            }
                        }
                        // Empty state
                        Text {
                            visible: status === "ready" && cur_models.length === 0
                            Layout.fillWidth: true
                            text: "no available model"
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                // Effort pane
                Item {
                    visible: pane === "effort"
                    Layout.fillWidth: true
                    implicitHeight: effortPaneColumn.height
                    ColumnLayout {
                        id: effortPaneColumn
                        width: parent.width
                        // Error strip (load errors)
                        Rectangle {
                            visible: errorMessage !== "" && lastAction === "load"
                            Layout.fillWidth: true
                            height: 40
                            color: "#ffeeee"
                            RowLayout {
                                anchors.fill: parent
                                Text { text: t("error.action", { "%1": errorMessage }); Layout.fillWidth: true; elide: Text.ElideRight }
                                Button { text: t("retry"); onClicked: reload() }
                            }
                        }
                        // Effort list
                        ListView {
                            id: effortListView
                            Layout.fillWidth: true
                            Layout.preferredHeight: Math.min(contentHeight, 200)
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: root.cur_efforts
                            delegate: Button {
                                id: effort_list_item

                                background: Rectangle {
                                    // 浅色专业风格配色
                                    //border.color: "#E5E7EB"
                                    border.width: 1
                                    radius: 16
                                    clip: true
                                    color: effort_list_item.hovered ? "#c0c0c0" : "#ffffff"
                                }

                                width: effortListView.width
                                enabled: status !== "selecting"
                                onClicked: {
                                    chooseEffort(modelData.name)
                                    root.open=false
                                }

                                Accessible.role: Accessible.MenuItem
                                focus: true
                                contentItem: RowLayout {
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Text { text: modelData.name; elide: Text.ElideRight }
                                    }
                                }
                            }
                        }
                        Text {
                            visible: !cur_efforts || cur_efforts.length === 0
                            Layout.fillWidth: true
                            text: t("empty.efforts")
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }

    // Toast
    Rectangle {
        id: toast
        visible: toastVisible
        anchors.bottom: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width - 20, 280)
        height: 40
        color: "#333333"
        radius: 4
        opacity: toastVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }
        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            Text {
                text: toastText
                color: "white"
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
        Timer {
            id: toastTimer
            interval: 3000
            onTriggered: toastVisible = false
        }
        onVisibleChanged: {
            if (toastVisible) {
                toastTimer.restart()
            }
        }
    }

    // Focus scope for keyboard
    focus: true
}
