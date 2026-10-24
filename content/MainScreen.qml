

/*
This is a UI file (.ui.qml) that is intended to be edited in Qt Design Studio only.
It is supposed to be strictly declarative and only uses a subset of QML. If you edit
this file manually, you might introduce QML code that is not supported by Qt Design Studio.
Check out https://doc.qt.io/qtcreator/creator-quick-ui-forms.html for details on .ui.qml files.
*/
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Qt.labs.platform as Labs
import Backend 1.0

Rectangle {
    id: root
    width: 1280
    height: 720

    color: "#ffffff"

    property var workspaces_sessions_json:null
    property var turns_steps_json:[
        {
            "id":0,
            "user_content":"user_content 1",
            steps:[
                {
                    "id":1,
                    "reasoning_content":"resoning_content 1",
                    "assistant_out":"assistant_out 1",
                    "tool_calls":[
                        {
                            id:"11112",
                            name:"glob(abc)",
                            content:"abc.txt"
                        },
                        {
                            id:"13332",
                            name:"glob(def)",
                            content:"def.txt"
                        }
                    ]
                },
                {
                    "id":2,
                    "reasoning_content":"resoning_content 2",
                    "assistant_out":"assistant_out 2",
                    "tool_calls":[
                        {
                            id:"55462",
                            name:"glob(abc)",
                            content:"abc.txt"
                        },
                        {
                            id:"9988732",
                            name:"glob(def)",
                            content:"def.txt"
                        }
                    ]
                }
            ]
        },
        {
            "id":0,
            "user_content":"user_content 1",
            steps:[
                {
                    "id":1,
                    "reasoning_content":"resoning_content 1",
                    "assistant_out":"assistant_out 1",
                    "tool_calls":[
                        {
                            id:"11112",
                            name:"glob(abc)",
                            content:"abc.txt"
                        },
                        {
                            id:"13332",
                            name:"glob(def)",
                            content:"def.txt"
                        }
                    ]
                },
                {
                    "id":2,
                    "reasoning_content":"resoning_content 2",
                    "assistant_out":"assistant_out 1",
                    "tool_calls":[
                        {
                            id:"55462",
                            name:"glob(abc)",
                            content:"abc.txt"
                        },
                        {
                            id:"9988732",
                            name:"glob(def)",
                            content:"def.txt"
                        }
                    ]
                }
            ]
        }
    ]

    property string provider: "" // name
    property var modelGroups:
    [
        {
            provider: "deepseek",
            chat_url: "https://api.deepseek.com/chat/completions",
            key:"xxxxxxxxxxx",
            max_context:1000000,
            models:[
                {
                    "name": "deepseek-flash",
                    "efforts": [
                        { "name": "none"},
                        { "name": "low"},
                        { "name": "high"},
                        { "name": "max"}
                    ],
                    "defaultEffort": "high"
                },
                {
                    "name": "deepseek-v4-pro",
                    "efforts": [
                        { "name": "none"},
                        { "name": "low"},
                        { "name": "high"},
                        { "name": "max"}
                    ],
                    "defaultEffort": "high"
                }
            ]
        }
    ]

    Component.onCompleted: {
        providers.load()
        sidebar.init_workspaces_sessions()
    }

    onProviderChanged: {
        console.info("当前提供商:",provider,"\n")
        //console.debug(modelGroups[provider],"\n")
        input_box.cur_provider_input_box=provider

        for(var i=0;i<modelGroups.length;i++){
            if(modelGroups[i].provider===root.provider){
                backend.change_provider(provider,modelGroups[i].chat_url,modelGroups[i].key,modelGroups[i].max_context)
                input_box.cur_models_input_box=modelGroups[i].models
                break
            }
        }
    }

    Backend {
        id:backend

        onAdd_turn: (_id,_user_content) => {
            turns_steps.add_a_turn(_id,_user_content)
        }

        onAdd_step: (_id,_reasoning_content,_assistant_out,_tool_call_json) => {
            turns_steps.add_a_step(_id,_reasoning_content,_assistant_out,_tool_call_json)
        }
    }

    Sidebar {
        id: sidebar

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width/5
        visible: true

        //workspaces_sessions_json:root.workspaces_sessions_json

        onLoad_workspaces_sessions: {
            let ret=backend.load_workspaces_sessions_json()
            if(ret.ok){
                sidebar.tmp_workspaces_sessions_json=ret.json
                console.info("加载工作区成功\n")
            }else{
                console.error("加载工作区失败\n")
            }
        }

        onStore_workspaces_sessions: (_jsonstr) => {
            let ret=backend.store_workspaces_sessions_jsonstr(_jsonstr)
            if(ret){
                console.info("保存工作区成功\n")
            }else{
                console.info("保存工作区失败\n")
            }
        }

        onAdd_workspace: (_folder_path,_name) => {
             sidebar.tmp_workspace_id=backend.add_workspace(_folder_path,_name)
        }

        onWorkspace_change: {
            console.log("workspace change\n")
        }

        onAdd_session: (_w_idx,_w_id,_name) => {
            sidebar.tmp_session_id=backend.add_session(_w_idx,_w_id,_name)

        }

        onChange_session: (_session_id,_path) => {
            //backend
            var ret = backend.change_session(_session_id,_path)
            if(ret.ok===true){
                console.log("改变会话成功\n")
                if(ret.json.length){
                    turns_steps.replace(ret.json)
                }else{
                    console.info("此会话无chat记录\n")
                    turns_steps.clear()
                }
            }else{
                console.error("改变会话失败\n")
            }
        }

        onCheckout_session: (_cur_id,_new_id) => {
            if(backend.checkout_session(_cur_id,_new_id)){
                console.info("会话签出成功，从id为",_cur_id,"到id为",_new_id)
            }else{
                console.info("会话签出失败，从id为",_cur_id,"到id为",_new_id)
            }
        }

        onChange_session_name: (_w_idx,_s_idx,_s_id,_name) => {
                                   let ret=backend.change_session_name(_w_idx,_s_idx,_s_id,_name)
                                   sidebar.sname_ok=ret
                               }

        onChange_workspace_name: (_w_idx,_w_id,_name) =>{
                                     let ret=backend.change_workspace_name(_w_idx,_w_id,_name)
                                     sidebar.wname_ok=ret
                                 }

        onDelete_session: (_w_idx,_s_idx,_s_id) => {
                              let ret=backend.delete_session(_w_idx,_s_idx,_s_id)
                              sidebar.ds_ok=ret
                          }

        onDelete_workspace: (_w_idx,_w_id) => {
                                let ret=backend.delete_workspace(_w_idx,_w_id)
                                sidebar.dw_ok=ret
                            }

        onZip: {
            zipped=true
            width=min_width
        }

        onExpand: {
            zipped=false
            width=parent.width/5
        }

        onSettings_requested: settings_window.visible=true

        Window {
            id: settings_window
            title: "设置"
            width: root.width / 2
            height: root.height * 2 / 3
            visible:false

            property int cur_index: -1

            Rectangle {
                id: settings_window_c
                anchors.fill: parent

                ListModel {
                    id: settings

                    ListElement {
                        name: "设置模型"
                    }
                }

                ColumnLayout {
                    id: options_layout

                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width:parent.width / 5

                    ListView {
                        id: side_options
                        model:settings
                        visible: true

                        Layout.fillHeight: true
                        Layout.fillWidth: true

                        delegate: ItemDelegate {
                            id: side_option_button

                            height: options_layout.height / 13

                            highlighted: index===settings_window.cur_index

                            onClicked: {
                                settings_window.cur_index=index
                            }

                            background: Rectangle {
                                border.width: 1
                                radius: 10
                                clip: true
                                color: side_option_button.hovered ? "#c0c0c0"
                                       : (side_option_button.highlighted ? "#c0c0c0" : "#ffffff")
                            }

                            contentItem: Text{
                                text: model.name
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                StackLayout {
                    id: setting_contents
                    currentIndex: settings_window.cur_index

                    anchors.left: options_layout.right
                    anchors.right: settings_window_c.right
                    anchors.top: settings_window_c.top
                    anchors.bottom: settings_window_c.bottom

                    Rectangle {
                        id: model_setting
                        Layout.fillHeight: true
                        Layout.fillWidth: true

                        RowLayout {
                            id: a
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top

                            //color: "#c0c0c0"

                            height:options_layout.height / 13

                            Button {
                                id: choose_provider

                                background: Rectangle {
                                    border.width: 1
                                    radius: 10
                                    clip: true
                                    color: choose_provider.hovered ? "#c0c0c0" : "#ffffff"
                                }

                                contentItem: Text {
                                    text:root.provider ? root.provider : "choose provider"
                                    font.pixelSize: 20
                                }

                                onClicked: providers_popup.open()
                            }

                            Popup {
                                id: providers_popup

                                x: choose_provider.x
                                y: choose_provider.y+choose_provider.height+5

                                height: providers_list.contentHeight
                                width: 150

                                background: Rectangle {
                                    border.width: 1
                                    radius: 16
                                    color: radius ? "#c0c0c0" : "#ffffff"
                                }

                                ListModel {
                                    id: providers

                                    function load(){
                                        let ret=backend.load_models_json()
                                        if(ret.ok){
                                            init(ret.json)
                                            //for models_scrollview
                                            root.modelGroups=ret.json
                                            //load_last_provider
                                            provider=providers.get(0).provider
                                            console.info("加载模型配置成功\n")
                                        }else{
                                            //
                                            let a=[]
                                            a=root.modelGroups
                                            init(a)
                                            provider="deepseek"
                                            console.warn("加载模型配置失败,将使用默认deepseek api\n")
                                        }
                                    }

                                    function init(ps){
                                        for(var i=0;i<ps.length;i++){
                                            if(Object.keys(ps[i]).length){
                                                append(ps[i])
                                            }
                                        }
                                    }
                                }

                                contentItem: ListView {
                                    id:providers_list
                                    anchors.fill: parent
                                    model:providers

                                    //implicitHeight: contentHeight

                                    delegate: Button {
                                        id:provider_button
                                        anchors.left: parent.left
                                        anchors.right: parent.right

                                        background: Rectangle {
                                            border.width: 1
                                            radius: 16
                                            color: provider_button.hovered ? "#c0c0c0" : "#ffffff"
                                        }

                                        contentItem: Text {
                                            text: model.provider
                                        }

                                        onClicked: {
                                            root.provider=model.provider
                                        }
                                    }
                                }
                            }

                            Button {
                                id: save_models_json

                                background: Rectangle {
                                    border.width: 1
                                    radius: 10
                                    clip: true
                                    color: save_models_json.hovered ? "#c0c0c0" : "#ffffff"
                                }

                                contentItem: Text {
                                    text:"保存设置"
                                    font.pixelSize: 20
                                }

                                onClicked: {
                                    //backend,保存为文件
                                    select_save_models_json.open()
                                }

                                FileDialog {
                                    id:select_save_models_json

                                    fileMode: Labs.FileDialog.SaveFile

                                    currentFile:backend.cur_dir()+"/models.json"

                                    nameFilters:["json文件 (*.json)"]

                                    onAccepted: {
                                        if(backend.store_models_jsonstr(models_text.text)){
                                            console.info("模型配置文件保存成功\n")
                                            let abc=backend.load_models_json()
                                            if(abc.ok){
                                                modelGroups=abc.json
                                                input_box.cur_provider_input_box=provider
                                                for(var i=0;i<modelGroups.length;i++){
                                                    if(modelGroups[i].provider===root.provider){
                                                        backend.change_provider(provider,modelGroups[i].chat_url,modelGroups[i].key,modelGroups[i].max_context)
                                                        input_box.cur_models_input_box=modelGroups[i].models
                                                        return
                                                    }
                                                }
                                                provider=providers.get(0).provider
                                            }else{
                                                console.error("重新加载模型配置失败\n")
                                            }
                                        }else{
                                            console.info("模型配置文件保存失败\n")
                                        }
                                    }
                                }
                            }
                        }

                        // 输入滚动区域
                        ScrollView {
                            id: models_scrollview
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: a.bottom
                            anchors.bottom: parent.bottom

                            ScrollBar.vertical.policy: ScrollBar.AlwaysOn
                            clip: true

                            // ScrollView中没有boundsBehavior
                            // 通过Binding强行修改内部Flickable的boundsBehavior，去除回弹
                            Binding {
                                target: models_scrollview.contentItem
                                property: "boundsBehavior"
                                value: Flickable.StopAtBounds
                            }

                            TextEdit {
                                id: models_text
                                //placeholderText: "模型设置"
                                text: JSON.stringify(root.modelGroups,null,4)
                                //placeholderTextColor: "#9CA3AF"
                                wrapMode: TextEdit.Wrap
                                //background: null // 去除默认背景
                                color: "#1F2937"
                                font.pixelSize: 25
                                selectByMouse: true
                                topPadding: 8
                                bottomPadding: 8
                            }

                        }
                    }
                }
            }
        }
    }



    Rectangle {
        id: except_sidebar_zone
        height: parent.height
        anchors.left: sidebar.right
        anchors.right: parent.right
        visible: true

        Rectangle {
            id: chat_zone
            width: parent.width*2/3
            visible: true
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.bottom: infos.top
            //color: "#a9a9a9"

            // ===================== 数据与状态 =====================

            property var turns_steps_json:root.turns_steps_json

            ListModel {
                id: turns_steps

                Component.onCompleted: {
//                    for(var i=0;i<turns_steps_json.length;i++){
//                        let turn={
//                            id:turns_steps_json[i].id,
//                            user_content:turns_steps_json[i].user_content,
//                            steps:create_steps(turns_steps_json[i].steps)
//                        }
//                        append(turn)
//                    }
                    //append(create(turns_steps_json))
                }

                function to_arr(a){
                    let b=[]
                    b=a
                    return b
                }

                function create_tool_call(tool_calls){
                    let t_c=[]
                    for(var k=0;k<tool_calls.length;k++){
                        let atc={
                            name:tool_calls[k].name,
                            args_result:JSON.stringify(tool_calls[k].args,null,4)+"\n"+tool_calls[k].result
                        }
                        console.debug(tool_calls[k].args)
                        console.debug(atc.args_result)
                        t_c.push(atc)
                    }
                    return t_c
                }

                function create_steps(steps){
                    let a_arr=[]
                    for(var i=0;i<steps.length;i++){
                        let s={
                            id:steps[i].id,
                            reasoning_content:steps[i].reasoning_content,
                            assistant_out:steps[i].assistant_out,
                            tool_call_json:create_tool_call(JSON.parse(steps[i].tool_call_json))
                        }
                        a_arr.push(s)
                    }
                    return a_arr
                }

                function objectToText(obj) {
                    var lines = ""
                    var keys = Object.keys(obj)
                    for (var i = 0; i < keys.length; ++i) {
                        var key = keys[i]
                        var val = obj[key]
                        if (val !== null && typeof val === "object")
                            val = JSON.stringify(val)
                        lines+=(key + ": " + val+"\n")
                    }
                    console.debug(lines.toString())
                    return lines.toString()
                }

                function replace(new_turns_steps){
                    clear()
                    for(var j=0;j<new_turns_steps.length;j++){
                        let t={
                            id:new_turns_steps[j].id,
                            user_content:new_turns_steps[j].user_content,
                            steps:create_steps(new_turns_steps[j].steps)
                        }
                        append(t)
                    }
                }

                function add_a_turn(_id,_user_content){
                    let arr=[]
                    let unfin={
                        id:_id,
                        user_content:_user_content,
                        steps:to_arr(arr)
                    }
                    append(unfin)
                }

                function add_a_step(_id,_reasoning_content,_assistant_out,_tool_call_json){
                    let a_step={
                        id:_id,
                        reasoning_content:_reasoning_content,
                        assistant_out:_assistant_out,
                        tool_call_json:create_tool_call(_tool_call_json)
                    }
                    turns_steps.get(turns_steps.count-1).steps.append(a_step)
                }
            }

            property bool   busy: false            // Agent 是否正在回复
            property bool   stickToBottom: true    // 是否自动贴底
            property string lastPrompt: ""

            function nowStr() {
                return Qt.formatTime(new Date(), "hh:mm")
            }

            //===================== =====================
            ListView {
                id: turns_listview
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.rightMargin: 16          // 给滚动条留出空间，避免遮挡内容
                anchors.top: parent.top
                anchors.bottom: input_box.top
                spacing: 24
                clip: true
                model: turns_steps

                // ===================== 右侧圆角滚动条 =====================
                // ScrollBar.vertical: ScrollBar {
                //     id: chat_zone_scroll_bar

                //     // 挂到 chat_zone 上，这样不会被 ListView 的 clip 裁掉，
                //     // 也能真正贴住 chat_zone 的右边界
                //     parent: chat_zone

                //     width: 8
                //     // anchors.right:  chat_zone.right
                //     // anchors.rightMargin: 4
                //     // anchors.top:    turns_listview.top
                //     // anchors.topMargin: 4
                //     // anchors.bottom: turns_listview.bottom
                //     // anchors.bottomMargin: 4
                //     Layout.alignment: Qt.AlignRight

                //     policy: ScrollBar.AsNeeded   // 内容超出才显示；想常显改成 AlwaysOn
                //     minimumSize: 0.05            // 滑块最小长度，防止内容超多时缩成一条线
                //     active: hovered || pressed

                //     opacity: vbar.active ? 1.0 : 0.45
                //     Behavior on opacity { NumberAnimation { duration: 200 } }

                //     // 轨道：透明即可
                //     background: Rectangle {
                //         implicitWidth: 8
                //         radius: width / 2        // 圆角（等于宽度的一半即胶囊形）
                //         color: "transparent"
                //     }

                //     // 滑块：圆角 + 状态变色 + 平滑过渡
                //     contentItem: Rectangle {
                //         implicitWidth: 8
                //         radius: width / 2
                //         color: vbar.pressed ? "#B0000000"
                //                             : vbar.hovered ? "#66000000"
                //                                            : "#33000000"
                //         Behavior on color { ColorAnimation { duration: 150 } }
                //     }
                // }
                // 自定义椭圆滚动条
                ScrollBar.vertical: ScrollBar {
                    id: chatzone_vbar
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 6
                        //implicitHeight: 100
                        radius: width / 2 // 椭圆/胶囊形状
                        color: chatzone_vbar.pressed ? "#9CA3AF" : "#D1D5DB"
                        opacity: chatzone_vbar.active ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                    }
                }

                delegate: Column {
                    width: turns_listview.width
                    spacing: 12

                    // 用户提问 (user_content)
                    Rectangle {
                        anchors.right: parent.right
                        width: Math.min(userText.implicitWidth + 24, parent.width * 0.8)
                        height: userText.implicitHeight + 20
                        color: "#007AFF"
                        radius: 12

                        TextEdit {
                            id: userText
                            anchors.centerIn: parent
                            width: parent.width - 20
                            text: model.user_content
                            font.pixelSize: 15
                            color: "#FFFFFF"
                            textFormat: Text.PlainText   // 关键：按纯文本解析，\n 会换行
                            wrapMode: Text.Wrap
                            readOnly: true
                            selectByMouse: true
                        }
                    }

                    // 内层：steps_listview
                    ListView {
                        id: steps_listview
                        width: parent.width
                        height: contentHeight
                        interactive: false
                        spacing: 16
                        model: steps

                        delegate: Column {
                            width: steps_listview.width
                            spacing: 8

                            // 1. 推理内容 (reasoning_content)
                            Rectangle {
                                width: parent.width
                                height: reasoningColumn.height
                                color: "#FFFFFF"
                                border.color: "#E0E0E0"
                                border.width: 1
                                radius: 8
                                clip: true

                                property bool isExpanded: false

                                Column {
                                    id: reasoningColumn
                                    width: parent.width

                                    Rectangle {
                                        width: parent.width
                                        height: 36
                                        color: "#F8F9FA"
                                        radius: 8

                                        Row {
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left
                                            anchors.leftMargin: 12
                                            spacing: 6
                                            Text {
                                                text: reasoningColumn.parent.isExpanded ? "∧" : "∨"
                                                font.pixelSize: 10
                                                color: "#666666"
                                            }
                                            Text {
                                                text: "思考 (Thinking)"
                                                font.pixelSize: 13
                                                font.bold: true
                                                color: "#555555"
                                                textFormat: Text.PlainText   // 关键：按纯文本解析，\n 会换行
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: reasoningColumn.parent.isExpanded = !reasoningColumn.parent.isExpanded
                                        }
                                    }

                                    TextEdit {
                                        width: parent.width - 24
                                        x: 12
                                        topPadding: 8
                                        bottomPadding: 12
                                        text: model.reasoning_content
                                        font.pixelSize: 13
                                        color: "#666666"
                                        textFormat: Text.PlainText   // 关键：按纯文本解析，\n 会换行
                                        wrapMode: Text.Wrap
                                        visible: reasoningColumn.parent.isExpanded
                                        readOnly: true
                                        selectByMouse: true
                                    }
                                }
                            }

                            // 2. 模型输出 (assistant_out)
                            TextEdit {
                                width: parent.width
                                leftPadding: 4
                                topPadding: 4
                                text: model.assistant_out
                                font.pixelSize: 14
                                color: "#222222"
                                textFormat: Text.PlainText   // 关键：按纯文本解析，\n 会换行
                                wrapMode: Text.Wrap
                                readOnly: true
                                selectByMouse: true

                            }

                            // 3. 工具调用 (tool_calls) - 整体可折叠
                            Rectangle {
                                width: parent.width
                                height: toolColumn.height
                                color: "#FFFFFF"
                                border.color: "#E5E5E5"
                                border.width: 1
                                radius: 8
                                clip: true

                                Column {
                                    id: toolColumn
                                    width: parent.width

                                    // 内层列表：tool_call_json
                                    ListView {
                                        id: tool_calls_listview
                                        width: parent.width
                                        height: contentHeight
                                        interactive: false
                                        model: tool_call_json
                                        spacing: 0

                                        delegate: Rectangle {
                                            width: tool_calls_listview.width
                                            height: itemColumn.height
                                            color: "transparent"
                                            border.color: "#F1F3F5"
                                            border.width: 1

                                            // 单个工具调用的折叠状态
                                            property bool isItemExpanded: false

                                            Column {
                                                id: itemColumn
                                                width: parent.width

                                                // 工具名称栏（点击可折叠下方内容）
                                                Rectangle {
                                                    width: parent.width
                                                    height: 36
                                                    color: "#FFFFFF" // 保持干净背景

                                                    Row {
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        anchors.left: parent.left
                                                        anchors.leftMargin: 16
                                                        spacing: 8

                                                        // 状态箭头
                                                        Text {
                                                            text: itemColumn.parent.isItemExpanded ? "∧" : "∨"
                                                            font.pixelSize: 10
                                                            color: "#007AFF"
                                                        }
                                                        // 工具名称
                                                        TextEdit {
                                                            text: model.name
                                                            font.pixelSize: 13
                                                            font.family: "Courier New"
                                                            color: "#007AFF"
                                                            font.bold: true
                                                            readOnly: true
                                                            selectByMouse: true
                                                        }
                                                    }

                                                    MouseArea {
                                                        anchors.fill: parent
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: itemColumn.parent.isItemExpanded = !itemColumn.parent.isItemExpanded
                                                    }
                                                }

                                                // 工具执行结果 content（放在 name 下面，可折叠）
                                                TextEdit {
                                                    id: contentText
                                                    width: parent.width - 36
                                                    x: 36 // 缩进对齐
                                                    topPadding: 4
                                                    bottomPadding: 10
                                                    text: model.args_result
                                                    font.pixelSize: 13
                                                    font.family: "Courier New"
                                                    color: "#555555"
                                                    textFormat: Text.PlainText   // 关键：按纯文本解析，\n 会换行
                                                    wrapMode: Text.Wrap
                                                    visible: itemColumn.parent.isItemExpanded
                                                    readOnly: true
                                                    selectByMouse: true
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ===================== 回到底部按钮 =====================
            Rectangle {
                id: toBottomBtn
                width: 36
                height: 36
                radius: width / 2                // 圆形
                color: "#FFFFFF"
                border.color: "#E0E0E0"
                border.width: 1
                z: 10                            // 保证盖在列表内容之上

                // 靠 input_box 上方，右侧对齐
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.bottom: input_box.top
                anchors.bottomMargin: 12

                // 已经在底部（或内容不足以滚动）时淡出；enabled 控制是否响应点击
                opacity: turns_listview.atYEnd ? 0 : 1
                enabled: opacity > 0.5
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "↓"
                    font.pixelSize: 18
                    font.bold: true
                    color: "#007AFF"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        chat_zone.stickToBottom = true         // 恢复自动贴底
                        turns_listview.positionViewAtEnd()     // 直达底部
                    }
                }
            }

            // ===================== 输入区 =====================
            Input_box {
                id:input_box
                anchors.left: parent.left
                anchors.right: parent.right
                //anchors.top: turns_listview.bottom
                anchors.bottom: parent.bottom
                radius: 14

                onCur_model_effortChanged: {

                }

                onSendMessage: (_model,_effort,_user_content,_permission_level) => {
                    backend.start_turn(_model,_effort,_user_content,_permission_level)
                }
            }

            // ===================== 模拟后端（替换成真实请求） =====================
            Timer {
                id: thinkTimer
                interval: 800
                property int msgIndex: -1
                onTriggered: {
                    streamTimer.msgIndex = msgIndex
                    streamTimer.fullText = chat_zone.fakeReply(chat_zone.lastPrompt)
                    streamTimer.cursor   = 0
                    chatModel.setProperty(msgIndex, "state", "streaming")
                    streamTimer.start()
                }
            }

            Timer {
                id: streamTimer
                interval: 20
                repeat: true
                property int    msgIndex: -1
                property string fullText: ""
                property int    cursor: 0

                onTriggered: {
                    cursor = Math.min(cursor + 2, fullText.length)
                    chatModel.setProperty(msgIndex, "text", fullText.substring(0, cursor))
                    if (chat_zone.stickToBottom)
                        listView.positionViewAtEnd()

                    if (cursor >= fullText.length) {
                        stop()
                        chatModel.setProperty(msgIndex, "state", "done")
                        chat_zone.busy = false
                    }
                }
            }
        }

        TextEdit {
            id: infos
            text: "aaaaaaaaaaaaaaaa"
            width: chat_zone.width
            //anchors.top: chat_zone.bottom
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            readOnly: true
            selectByMouse: true
        }

    }
    //states: [
    //]
}
