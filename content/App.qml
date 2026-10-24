// Copyright (C) 2021 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR GPL-3.0-only
import QtQuick
import QtQuick.Controls
import Kw_agent

ApplicationWindow {
    width: Constants.width
    height: Constants.height

    visible: true
    title: "kw-agent"

    color: "#ffffff"

    onWidthChanged: contentItem.update()
    onHeightChanged: contentItem.update()

    MainScreen {
        id: main_screen
        anchors.fill: parent
        visible: true

        layer.enabled: true
        layer.smooth: true
    }




}

