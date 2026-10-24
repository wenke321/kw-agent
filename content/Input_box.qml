import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    //上层需要
    property var cur_model_effort:[]

    //全局修改,工作区修改，工作区只读：0，1，2;上层需要
    property int permission_level:2

    //for ModelSelect
    property var cur_models_input_box:null
    property string cur_provider_input_box:""
    onCur_models_input_boxChanged: {
        //console.log("cur_models in input_box:",cur_models_input_box,"\n")
        model_select.cur_models=cur_models_input_box
    }
    onCur_provider_input_boxChanged: {
        //console.log("cur_provider in input_box:",cur_provider_input_box,"\n")
        model_select.cur_provider=cur_provider_input_box
    }

    // 浅色专业风格配色
    color: "#FFFFFF"
    border.color: "#E5E7EB"
    border.width: 1
    radius: 16

    // 默认最小高度
    property int minHeight: 56
    // 最大高度限制为父容器的一半（如果没有父容器则默认300，防止报错）
    property real maxHeight: parent.height / 2

    // 对外暴露输入框文字和信号
    property alias text: textArea.text
    property alias placeholderText: textArea.placeholderText

    signal sendMessage(_model:string,_effort:string,_user_content:string,_permission_level:int)
    signal change_permission_level(_permission_level:int)

    implicitHeight: layout.implicitHeight
    implicitWidth: parent ? parent.width : 500

    ColumnLayout {
        id: layout
        anchors.fill: parent
        spacing: 0

        // 输入滚动区域
        ScrollView {
            id: scrollView
            Layout.fillWidth: true
            //Layout.margins: 12

            // 核心逻辑：高度自适应，上限为 maxHeight 减去底部工具栏的高度
            Layout.preferredHeight: Math.max(
                40, // 单行时的最小高度
                Math.min(
                    textArea.implicitHeight + 16, // 文本高度 + 上下内边距
                    root.maxHeight - bottomBar.height - 24 // 减去底部栏和边距，防止整体超出限制
                )
            )

            clip: true

            // 解决ScrollView中没有boundsBehavior的问题
            // 通过Binding强行修改内部Flickable的boundsBehavior，去除回弹
            Binding {
                target: scrollView.contentItem
                property: "boundsBehavior"
                value: Flickable.StopAtBounds
            }

            TextArea {
                id: textArea
                placeholderText: "输入消息..."
                placeholderTextColor: "#9CA3AF"
                wrapMode: TextEdit.Wrap
                background: null // 去除默认背景
                color: "#1F2937"
                font.pixelSize: 15
                selectByMouse: true
                topPadding: 8
                bottomPadding: 8
            }

            // 自定义椭圆滚动条
            ScrollBar.vertical: ScrollBar {
                id: vbar
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle {
                    implicitWidth: 6
                    //implicitHeight: 100
                    radius: width / 2 // 椭圆/胶囊形状
                    color: vbar.pressed ? "#9CA3AF" : "#D1D5DB"
                    opacity: vbar.active ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }
        }

        // 底部工具栏
        RowLayout {
            id: bottomBar
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            Layout.leftMargin: 12
            Layout.rightMargin: 12
            spacing: 8

            // 加号按钮 (工作区添加)

            ListModel{
                id:extra_cmds
                ListElement{
                    name:"设置或查看长期目标"
                }
                ListElement{
                    name:"添加文件"
                }
            }

            Button {
                id:extra_cmds_button
                text: "＋"
                font.pixelSize: 20
                palette.buttonText: "#6B7280"

                background: Rectangle {
                    // 浅色专业风格配色
                    border.width: 1
                    radius: 14
                    clip: true
                    color: extra_cmds_button.hovered ? "#c0c0c0" : "#ffffff"
                }

                onClicked: extra_cmds_popup.open()

                ToolTip {
                    visible: extra_cmds_popup.opened ? false : extra_cmds_button.hovered
                    text: "其他指令"

                    background: Rectangle {
                        // 浅色专业风格配色
                        border.width: 1
                        radius: 14
                        clip: true
                        color: radius ? "#c0c0c0" : "#ffffff"
                    }
                }
            }

            Popup {
                id:extra_cmds_popup

                x:extra_cmds_button.x
                y:-height - 6

                width: 150
                height: extra_cmds_list.contentHeight

                parent:extra_cmds_button

                focus:true

                background: Rectangle {
                    color: "#FFFFFF"
                    border.color: "#E5E7EB"
                    border.width: 1
                    radius: 10
                }

                contentItem: ListView {
                    id:extra_cmds_list
                    anchors.fill: parent
                    model:extra_cmds

                    implicitHeight: contentHeight


                    delegate: Button {
                        id: cmd_item
                        anchors.left: parent.left
                        anchors.right: parent.right
                        implicitHeight: 30

                        background: Rectangle {
                            color: cmd_item.hovered ? "#c0c0c0" : "#FFFFFF"
                            radius: 12
                        }

                        contentItem: Text {
                            text: model.name
                            //anchors.left: parent.left
                        }
                    }
                }
            }

            // 工作区内修改 下拉菜单
            ListModel {
                id: permissionModel
                ListElement { name: "全局修改"; level: 0 }
                ListElement { name: "工作区内修改"; level: 1 }
                ListElement { name: "工作区内只读"; level: 2 }
            }

            Button {
                id: permission_select
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                implicitWidth: 90
                implicitHeight: 36
                padding: 0

                text: {
                    switch (permission_level) {
                    case 0: return "全局修改"
                    case 1: return "工作区内修改"
                    case 2: return "工作区内只读"
                    default: return "未知权限"
                    }
                }

                onClicked: permissions_popup.open()

                background: Rectangle {
                    // 浅色专业风格配色
                    border.width: 1
                    radius: 16
                    clip: true
                    color: permission_select.hovered ? "#c0c0c0" : "#ffffff"
                }

                contentItem: Text {
                    text: permission_select.text
                    color: "#111827"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }

            Popup {
                id: permissions_popup
                parent: permission_select
                width: Math.max(permission_select.width, 130)
                height: Math.min(permission_list.contentHeight + topPadding + bottomPadding, 240)
                x: (permission_select.width - width) / 2
                y: -height - 6
                focus: true
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                background: Rectangle {
                    // 浅色专业风格配色
                    border.width: 1
                    radius: 16
                    clip: true
                    color: radius ? "#c0c0c0" : "#ffffff"
                }

                contentItem: ListView {
                    id: permission_list
                    anchors.fill: parent
                    clip: true
                    model: permissionModel
                    implicitHeight: contentHeight
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Button {
                        id: itemButton
                        width: permission_list.width
                        anchors.left: parent.left
                        anchors.right: parent.right
                        implicitHeight: 36
                        flat: true
                        highlighted: permission_level === model.level

                        background: Rectangle {
                            color: itemButton.hovered
                                   ? "#c0c0c0"
                                   : (itemButton.highlighted ? "#EFF6FF" : "transparent")
                            radius: 16
                        }

                        contentItem: Text {
                            text: model.name
                            color: itemButton.highlighted ? "#2563EB" : "#111827"
                            font.pixelSize: 14
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            //leftPadding: 12
                            //rightPadding: 12
                            elide: Text.ElideRight
                        }

                        onClicked: {
                            permission_level = model.level
                            permissions_popup.close()
                        }
                    }
                }
            }

            //
            Item { Layout.fillWidth: true } // 弹簧占位，把右侧元素推到底部

            // 模型,思考强度
            ModelSelect {
                id: model_select
                Layout.preferredHeight: 25
                status: "ready"

                onModel_change: {
                    root.cur_model_effort[0]=model_select.cur_model
                }

                onEffort_change: {
                    root.cur_model_effort[1]=model_select.cur_effort
                }

                x:sendBtn.x - width - 6
            }

            // 发送按钮
            RoundButton {
                id: sendBtn
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                Layout.alignment: Qt.AlignVCenter

                background: Rectangle {
                    color: sendBtn.enabled ? "#2563EB" : "#93C5FD"
                    radius: width / 2
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                contentItem: Text {
                    text: "↑"
                    color: "#FFFFFF"
                    font.pixelSize: 18
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                enabled: textArea.text.trim() !== ""

                onClicked: {
                    root.sendMessage(root.cur_model_effort[0],root.cur_model_effort[1],textArea.text.trim(),root.permission_level)
                    textArea.text = "" // 发送后清空
                }

                MouseArea {
                    anchors.fill: parent;
                    cursorShape: Qt.PointingHandCursor
                    // 传递点击事件给RoundButton
                    onClicked: sendBtn.clicked()
                }
            }
        }
    }
}
