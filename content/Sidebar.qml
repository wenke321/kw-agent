import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Item {
    id: root

    property variant tmp_workspaces_sessions_json:[]

    property var selected_session_pre_idx:[]

    property bool zipped: false
    property int min_width: 68
    //expose
    property string cur_dir: ""

    onZippedChanged: {
        if(zipped){

        }
    }

    signal settings_requested()
    signal expand()
    signal zip()

    signal workspace_change()

    property int cur_session_id:-1
    signal change_session(session_id:int,path:string)

    property int tmp_workspace_id:-1
    signal add_workspace(_folder_path:string,_name:string)

    property int tmp_session_id:-1
    signal add_session(_workspace_idx:int,_workspace_id:int,_session_name:string)

    property bool sname_ok:false
    signal change_session_name(_w_idx:int,_s_idx:int,_s_id:int,_name:string)

    signal checkout_session(_cur_id:int,_new_id:int)

    property bool wname_ok:false
    signal change_workspace_name(_w_idx:int,_w_id:int,_name:string)

    property bool dw_ok:false
    signal delete_workspace(_w_idx:int,_w_id:int)

    property bool ds_ok:false
    signal delete_session(_w_idx:int,_s_idx:int,_s_id:int)

    signal store_workspaces_sessions(_jsonstr:string)
    signal load_workspaces_sessions()

    function init_workspaces_sessions(){
        load_workspaces_sessions()
        //console.debug("workspaces_sessions :\n",JSON.stringify(tmp_workspaces_sessions_json,null,4))
        workspaces_sessions.init(tmp_workspaces_sessions_json)
        tmp_workspaces_sessions_json=null
    }

    ListModel {
        id: workspaces_sessions

        Component.onDestruction: {
            var arr = []
            for (var i = 0; i < workspaces_sessions.count; i++) {
                var item = workspaces_sessions.get(i)
                var obj = {
                    id:item.id,
                    name:item.name,
                    path:item.path,
                    sessions:resolve_sessions(item.sessions)
                }
                arr.push(obj)
            }
            store_workspaces_sessions(JSON.stringify(arr,null,4))
        }

        function init(w_s){
            if(w_s.length){
                for(var i=0;i<w_s.length;i++){
                    let w={
                        id:w_s[i].id,
                        name:w_s[i].name,
                        path:w_s[i].path,
                        sessions:create(w_s[i].sessions)
                    }
                    append(w)
                }
            }else{
                console.info("no workspace now\n")
            }
        }

        function create(s){
            let c=[]
            c=s
            for(var i=0;i<c.length;i++){
                c[i].selected=false
            }
            return c
        }

        function resolve_sessions(s){
            let a=[]
            for(var i=0;i<s.length;i++){
                let b={
                    id:s[i].id,
                    name:s[i].name
                }
                a.push(b)
            }
            return a
        }
    }

    Rectangle {
        id: zipped_content
        anchors.fill: parent
        visible: root.zipped
        color: "#ffffff"
        //spacing: 10

        ToolButton {
            //anchors.margins: undefined
            id: expand_sidebar
            height: 48
            width: parent.width
            anchors.top: parent.top
            text: "⏵"
            onClicked: {
                root.expand()
                console.log("展开按钮点击")
            }
        }

        Button {
            id: add_workspace_zipped
            height: 48
            width: parent.width
            text: "➕"
            anchors.top: expand_sidebar.bottom
            onClicked: {
                root.expand()
                folder_dialog_zip.open()
            }

            FolderDialog {
                id: folder_dialog_zip
                title: "选择文件夹"
                onAccepted: {
                    root.cur_dir=selectedFolder.toString().replace("file:///","")
                    for(var i=root.cur_dir.length-1;i>-1;i--){
                        if(root.cur_dir[i]==='/'){
                            let nname=root.cur_dir.substring(i+1,root.cur_dir.length)
                            workspaces_sessions.append({id:-1,name:nname,
                                                           path:root.cur_dir,sessions:[]})
                            //backend,create workspace
                            //signal
                            add_workspace(root.cur_dir,nname)
                            //fail
                            if(root.tmp_workspace_id===-1){
                                console.error("add workspace failed,will rollback,see logs about sqlite3\n")
                                workspaces_sessions.remove(workspaces_sessions.count-1)
                            }else{
                                workspaces_sessions.setProperty(workspaces_sessions.count-1,"id",root.tmp_workspace_id)
                                console.info("add workspace success\n");
                                console.debug("new w_id:",root.tmp_workspace_id)
                                root.tmp_workspace_id=-1
                            }
                            break
                        }
                    }
                }
            }

            //hoverEnabled: true
        }

        Button {
            id: setting_zipped
            height: 48
            width: parent.width
            text: "⚙ 设置"
            anchors.bottom: parent.bottom
            onClicked: root.settings_requested()
        }

    }

    Rectangle {
        id: full_content
        anchors.fill: parent
        visible: !root.zipped
        //Layout.fillHeight: true
        color: "#ffffff"
        clip: true

        property var selected_session_pre_idx:[]

        Behavior on Layout.preferredWidth {
            NumberAnimation {
                duration: 200
                easing.type: Easing.InOutQuad
            }
        }

        RowLayout {
            id: a
            width: parent.width

            Text {
                text: "kw-agent"
                font.bold: true
                font.pixelSize: 18
                Layout.fillWidth: true
                visible: true
            }

            ToolButton {
                id: zip_sidebar
                text: "⏴"
                onClicked: {
                    root.zip()
                    console.log("收缩按钮点击")
                }
            }
        }

        RowLayout {
            id: b
            width: parent.width
            anchors.top: a.bottom
            anchors.topMargin: 10

            Text {
                text: "工作区"
                color: "#666"
                font.pixelSize: 14
                Layout.fillWidth: true
            }

            ToolButton {
                id: add_workspace_btn
                text: "➕"

                onClicked: folder_dialog.open()

                FolderDialog {
                    id: folder_dialog
                    title: "选择文件夹"

                    function abc(){
                        var abc=[]
                        abc.push({ id:root.tmp_session_id,name:"新会话",selected:true})
                        return abc
                    }

                    onAccepted: {
                        root.cur_dir=selectedFolder.toString().replace("file:///","")
                        for(var i=root.cur_dir.length-1;i>-1;i--){
                            if(root.cur_dir[i]==='/'){
                                let nname=root.cur_dir.substring(i+1,root.cur_dir.length)
                                workspaces_sessions.append({id:-1,name:nname,
                                                            path:root.cur_dir,
                                                            sessions:[]})
                                //backend,create workspace
                                //signal
                                root.add_workspace(root.cur_dir,nname)
                                //fail
                                if(root.tmp_workspace_id===-1){
                                    console.error("增加工作区失败\n")
                                    workspaces_sessions.remove(workspaces_sessions.count-1)
                                }else{
                                    workspaces_sessions.setProperty(workspaces_sessions.count-1,"id",root.tmp_workspace_id)
                                    console.info("增加工作区成功\n");
                                    //console.debug("new w_id:",tmp_workspace_id)
                                    root.tmp_workspace_id=-1
                                }
                                break
                            }
                        }
                    }
                }
            }
        }

        ListView {
            id: workspaces_listview
            width: parent.width
            anchors.top: b.bottom
            anchors.bottom: setting.top
            model: workspaces_sessions

            Component.onCompleted: {
                root.selected_session_pre_idx[0]=-1
                root.selected_session_pre_idx[1]=-1
            }

            delegate: Rectangle {
                id: workspaceContainer
                //width: parent.width
                height: workspaceHeader.height+sessions_listview.height
                anchors.left: parent.left
                anchors.right: parent.right
                clip: true

                property bool isExpanded: true
                property int ws_index:index

                function click_add_session_btn() {
                    add_session_btn.click()
                }

                Dialog {
                    id:  workspace_rename
                    title: "重命名会话"
                    modal: true
                    standardButtons: Dialog.Ok | Dialog.Cancel
                    anchors.centerIn: parent

                    // 预填当前名称
                    property alias newName: wk_name_field.text

                    contentItem: TextField {
                        id: wk_name_field
                        text: model.name
                        placeholderText: "输入新名称"
                        selectByMouse: true
                        focus: true
                    }

                    onAccepted: {
                        let old_name=workspaces_sessions.get(index).name
                        if (wk_name_field.text.trim() !== "") {
                            workspaces_sessions.setProperty(index, "name", wk_name_field.text.trim())
                            //backend,change workspace name
                            change_workspace_name(index,workspaces_sessions.get(index).id,wk_name_field.text.trim())
                            if(!root.wname_ok){
                                console.error("工作区改名失败\n")
                                workspaces_sessions.setProperty(index, "name", old_name)
                            }else{
                                console.info("工作区改名成功\n")
                            }
                        }
                    }
                }

                // 工作区标题行
                Rectangle {
                    id: workspaceHeader
                    //Layout.fillWidth: true
                    //Layout.preferredHeight: 25
                    height: 25
                    anchors.left: parent.left
                    anchors.right: parent.right
                    color: isHovered ? "#eef2f7" : "transparent"


                    property bool isHovered: workspaceHeader_hover.hovered
                    HoverHandler { id: workspaceHeader_hover }

                    Keys.onLeftPressed: {
                        //backend,change workspace
                        root.workspace_change()
                        console.log("change workspace\n")
                    }

                    Button {
                        id: expand_sessions
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        opacity: parent.isHovered ? 1:0
                        width: 25
                        onClicked: {
                            workspaceContainer.isExpanded = !workspaceContainer.isExpanded
                        }

                        background: Rectangle {
                            implicitWidth: 100
                            implicitHeight: 40
                            color: add_session_btn.hovered ? "#d0d0d0" : "#ffffff"
                        }

                        contentItem: Image{
                            anchors.fill: parent
                            source: workspaceContainer.isExpanded ? "images/down_triangle.png" : "images/right_triangle.png"
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                    }

                    Text {
                        id: workspace_name
                        text: model.name
                        anchors.left: expand_sessions.right
                        anchors.right: workspaceHeader_menu.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                    }

                    Button {
                        id: workspaceHeader_menu
                        anchors.right: add_session_btn.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width:25
                        visible: parent.isHovered
                        onClicked: workspaceMenu.open()

                        background: Rectangle {
                            anchors.fill: parent
                            color: add_session_btn.hovered ? "#d0d0d0" : "#ffffff"
                        }

                        contentItem: Image{
                            anchors.fill: parent
                            source: "images/other.png"
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }

                        Menu {
                            id: workspaceMenu
                            y: workspaceHeader_menu.height
                            MenuItem {
                                text: "重命名"
                                onTriggered: {
                                    console.log("重命名：" + model.name)
                                    workspace_rename.open()
                                }
                            }
                            MenuItem {
                                text: "删除"
                                onTriggered: {
                                    //backend, delete workspace
                                    delete_workspace(index,workspaces_sessions.get(index).id)
                                    if(root.dw_ok){
                                        // 通过 ListView 的模型删除当前项
                                        workspaces_listview.model.remove(index)
                                        console.info("删除工作区成功\n")
                                    }else{
                                        console.error("删除工作区失败\n")
                                    }
                                }
                            }
                        }
                    }

                    Button {
                        id: add_session_btn
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width:25
                        visible: parent.isHovered
                        background: Rectangle {
                            implicitWidth: 100
                            implicitHeight: 40
                            color: add_session_btn.hovered ? "#d0d0d0" : "#ffffff"
                        }


                        onClicked: {
                            //sessions_listview.height+=25
                            let s=workspaces_sessions.get(index).sessions

                            //backend,create session
                            //signal
                            add_session(index,workspaces_sessions.get(index).id,"新会话")
                            if(root.tmp_session_id===-1){
                                console.error("会话创建失败\n")
                            }else{
                                s.append({ id:root.tmp_session_id,name:"新会话",selected:true})
                                console.info("会话创建成功\n")
                                console.debug("new s_id:",root.tmp_session_id)
                                if(root.selected_session_pre_idx[0]!==-1){
                                    console.debug("pre_index=",root.selected_session_pre_idx[0],",",root.selected_session_pre_idx[1],"\n")
                                    workspaces_sessions.get(root.selected_session_pre_idx[0])
                                    .sessions.setProperty(root.selected_session_pre_idx[1],"selected",false)
                                }

                                root.selected_session_pre_idx[0]=index
                                root.selected_session_pre_idx[1]=s.count-1
                                //backend,change turns_steps
                                root.change_session(root.tmp_session_id,workspaces_sessions.get(root.selected_session_pre_idx[0]).path)
                                console.debug("change session,","now_index=",root.selected_session_pre_idx[0],","
                                            ,root.selected_session_pre_idx[1],"\n")
                            }


                            //root.tmp_session_id=-1
                            workspaceContainer.isExpanded=true
                        }

                        contentItem: Image{
                            anchors.fill: parent
                            source: "images/+.png"
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                    }
                }

                // 会话列表
                ListView {
                    id: sessions_listview
                    height: workspaceContainer.isExpanded ? contentHeight : 0
                    model: sessions
                    visible: workspaceContainer.isExpanded
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: workspaceHeader.bottom

                    property int ws_index:workspaceContainer.ws_index

                    property alias addSessionBtn: add_session_btn

                    delegate: Button {
                        id: session
                        height: 25
                        anchors.left: parent.left
                        anchors.right: parent.right

                        background: Rectangle{
                            color: model.selected ? "#eef2f7" : (isHovered ? "#eef2f7" : "transparent")
                        }

                        property bool isHovered: _hover.hovered
                        HoverHandler { id: _hover }
                        property bool is_rename: false

                        property int cur_widx:ListView.view.ws_index

//                        Keys.onLeftPressed: {
                        onClicked: {
                            if(root.selected_session_pre_idx[0]!==-1){
                                console.log("pre_index=",root.selected_session_pre_idx[0],",",root.selected_session_pre_idx[1],"\n")
                                workspaces_sessions.get(root.selected_session_pre_idx[0])
                                .sessions.setProperty(root.selected_session_pre_idx[1],"selected",false)
                            }

                            root.selected_session_pre_idx[0]=ListView.view.ws_index
                            root.selected_session_pre_idx[1]=index

                            sessions.setProperty(index,"selected",true)

                            //backend,change turns_steps
                            root.change_session(model.id,workspaces_sessions.get(root.selected_session_pre_idx[0]).path)
                            console.debug(model.selected)
                            console.log("change session,","now_index=",root.selected_session_pre_idx[0],","
                                        ,root.selected_session_pre_idx[1],"\n")
                        }

                        Dialog {
                            id: session_rename
                            title: "重命名会话"
                            modal: true
                            standardButtons: Dialog.Ok | Dialog.Cancel
                            anchors.centerIn: parent

                            // 预填当前名称
                            property alias newName: session_name_field.text

                            contentItem: TextField {
                                id: session_name_field
                                text: model.name
                                placeholderText: "输入新名称"
                                selectByMouse: true
                                focus: true
                            }

                            onAccepted: {
                                // 用户点击“确定”，更新模型
                                let old_name=sessions.get(index).name
                                if (session_name_field.text.trim() !== "") {
                                    sessions.setProperty(index, "name", session_name_field.text.trim())

                                    //backend,change session name
                                    change_session_name(parent.cur_widx,index,sessions.get(index).id,session_name_field.text.trim())
                                    if(!root.sname_ok){
                                        console.error("会话改名失败\n")
                                        sessions.setProperty(index, "name", old_name)
                                    }else{
                                        console.info("会话改名成功\n")
                                    }
                                }
                                sessions.get(index).focus=false
                            }
                        }

                        Text {
                            id: session_name
                            text: model.name
                            anchors.left: parent.left
                            anchors.leftMargin: 25
                            anchors.right: session_setting.left
                        }

                        Button {
                            id: session_setting
                            width: 25
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            visible: parent.isHovered
                            onClicked: session_menu.open()

                            contentItem: Image{
                                anchors.fill: parent
                                source: "images/other.png"
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }

                            Menu {
                                id: session_menu
                                y: session_setting.height

                                MenuItem {
                                    text: "重命名"
                                    onTriggered: {
                                        sessions.get(index).focus=true
                                        session_rename.open()
                                    }
                                }

                                MenuItem {
                                    text: "删除"
                                    onTriggered: {
                                        //backend, delete session
                                        delete_session(ListView.view.ws_index,index,sessions.get(index).id)
                                        if(root.ds_ok){
                                            sessions_listview.model.remove(index)
                                            console.info("删除会话成功\n")
                                        }else{
                                            console.error("删除会话失败\n")
                                        }
                                    }
                                }

                                MenuItem {
                                    text: "签出会话"
                                    onTriggered: {
                                        let cur_id=sessions.get(index).id

                                        sessions_listview.addSessionBtn.click()

                                        if (root.tmp_session_id !== -1) {
                                            checkout_session(cur_id, root.tmp_session_id)
                                        } else {
                                            console.error("签出会话失败：新建会话失败")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        ToolButton {
            id: setting
            text: "⚙ 设置"
            width: parent.width
            anchors.bottom: parent.bottom
            onClicked: settings_requested()

//            contentItem: Image{
//                anchors.left: parent.left
//                source: "images/setting.svg"
//                fillMode: Image.PreserveAspectFit
//                width: parent.width/10
//                height: parent.height
//                smooth: true
//            }
        }
    }


}
