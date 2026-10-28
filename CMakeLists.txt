cmake_minimum_required(VERSION 3.21.1)

include(ProcessorCount)


#my_change
#set(CMAKE_PROJECT_INCLUDE_BEFORE ${CMAKE_CURRENT_SOURCE_DIR}/.qtcreator/cmake-helper/qtcreator-project.cmake)

set(CMAKE_BUILD_PARALEL_LEVEL ProcessorCount(NPROC))

set(CMAKE_GENERATOR "Ninja" CACHE INTERNAL "")

find_program(CCACHE ccache)
if(CCACHE)
  set(CMAKE_CXX_COMPILER_LAUNCHER ${CCACHE})
  set(CMAKE_C_COMPILER_LAUNCHER ${CCACHE})
endif()
#my_change

#my_change
if (${CMAKE_BUILD_TYPE} STREQUAL "Debug")
# Debug 配置
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION_DEBUG OFF)
elseif (${CMAKE_BUILD_TYPE} STREQUAL "Release")
# Release 配置
else ()
# 其他配置
endif ()
#my_change

set(QML_IMPORT_PATH "imports")

set(BUILD_QDS_COMPONENTS ON CACHE BOOL "Build design studio components")
option(LINK_INSIGHT "Link Qt Insight Tracker library" ON)

project(Kw_agentApp LANGUAGES CXX)

set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_AUTOMOC ON)

find_package(QT NAMES Qt6 COMPONENTS Gui Qml Quick)
find_package(Qt6 REQUIRED COMPONENTS Core Qml Quick)

# To build this application you need Qt 6.2.0 or higher
if (Qt6_VERSION VERSION_LESS 6.2.0)
message(FATAL_ERROR "You need Qt 6.2.0 or newer to build the application.")
endif()

qt_add_executable(${CMAKE_PROJECT_NAME} src/main.cpp
    src/backend.h)

# qt_standard_project_setup() requires Qt 6.3 or higher. See https://doc.qt.io/qt-6/qt-standard-project-setup.html for details.
if (${QT_VERSION_MINOR} GREATER_EQUAL 3)
qt6_standard_project_setup()
endif()

qt_add_resources(${CMAKE_PROJECT_NAME} "configuration"
    PREFIX "/"
    FILES
        qtquickcontrols2.conf
)

target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE
    Qt${QT_VERSION_MAJOR}::Core
    Qt${QT_VERSION_MAJOR}::Gui
    Qt${QT_VERSION_MAJOR}::Quick
    Qt${QT_VERSION_MAJOR}::Qml
)

#my_change
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}  -fno-omit-frame-pointer -fno-optimize-sibling-calls")
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS}  -fno-omit-frame-pointer -fno-optimize-sibling-calls")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ")
#my_change

#my_change_start
target_precompile_headers(${CMAKE_PROJECT_NAME} PRIVATE
    #QtCore
    <QtCore/QObject>
    <QtCore/QString>
    <QtCore/QStringList>
    <QtCore/QUrl>
    <QtCore/QVariant>
    <QtCore/QVariantMap>
    <QtCore/QList>
    <QtCore/QVector>
    <QtCore/QHash>
    <QtCore/QMap>
    <QtCore/QDebug>
    <QtCore/QPointer>
    <QtCore/QTimer>
    <QtCore/QDateTime>
    <QtCore/QFile>
    <QtCore/QDir>
    <QtCore/QStandardPaths>
    <QtCore/QSettings>
    <QtCore/QJsonDocument>
    <QtCore/QJsonObject>
    <QtCore/QJsonArray>
    <QtCore/QAbstractListModel>
    <QtCore/QSortFilterProxyModel>

    #QtGui
    <QtGui/QGuiApplication>
    <QtGui/QColor>
    <QtGui/QFont>
    <QtGui/QIcon>
    <QtGui/QImage>
    <QtGui/QPixmap>
    <QtGui/QPainter>
    <QtGui/QKeyEvent>
    <QtGui/QMouseEvent>
    <QtGui/QScreen>

    #QtQml
    <QtQml/QQmlEngine>
    <QtQml/QQmlContext>
    <QtQml/QQmlComponent>
    <QtQml/QQmlApplicationEngine>
    <QtQml/QQmlProperty>
    <QtQml/QQmlListProperty>
    <QtQml/QJSEngine>
    <QtQml/QJSValue>
    <QtQml/qqml.h>

    #QtQuick
    <QtQuick/QQuickItem>
    <QtQuick/QQuickWindow>
    <QtQuick/QQuickView>
    <QtQuick/QQuickPaintedItem>
    <QtQuick/QQuickImageProvider>
    <QtQuick/QSGNode>

    #
    <QThreadPool>
    <QtConcurrent/QtConcurrentRun>
)
#my_change_end

if (${BUILD_QDS_COMPONENTS})
    include(${CMAKE_CURRENT_SOURCE_DIR}/qmlcomponents)
endif ()

include(${CMAKE_CURRENT_SOURCE_DIR}/qmlmodules)

if (LINK_INSIGHT)
    include(${CMAKE_CURRENT_SOURCE_DIR}/insight)
endif ()

install(TARGETS ${CMAKE_PROJECT_NAME}
    BUNDLE  DESTINATION ${CMAKE_INSTALL_BINDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
