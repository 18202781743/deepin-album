import QtQuick 2.11
import QtQuick.Window 2.11
import QtQuick.Controls 2.4
import QtQuick 2.0
import QtQuick.Window 2.11
import QtQuick.Layouts 1.11
import QtQuick.Controls 2.0
import org.deepin.dtk 1.0
import "./Control"

Rectangle {

    width:200
    height:parent.height
    ScrollView {
        width:200
        height:parent.height
        //    color: "#EEEEEE"
        clip: true

        Column {
            width:parent.width
            id: colum
            spacing: 0
            anchors.top: parent.top
            anchors.topMargin: 69
            anchors.left: parent.left
            anchors.leftMargin: 20
            Label {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 15
                id:pictureLabel
                height: 30
                text: qsTr("Gallery")

                color: Qt.rgba(0,0,0,0.3)
                lineHeight: 20

            }

            ListView{
                id : pictureLeftlist
                width: parent.width-20
                implicitHeight: contentHeight
                model: SidebarModel {}
                delegate:ItemDelegate {
                    text: name
                    width: parent.width
                    icon.name: iconName
                    checked: index == 0
                    backgroundVisible: false
                    onClicked: {
                        global.currentViewIndex = index + 2
                        // 导航页选中我的收藏时，设定自定相册索引为0，使用CutomAlbum控件按自定义相册界面逻辑显示我的收藏内容
                        if (global.currentViewIndex == 4) {
                            global.currentCustomAlbumUId = 0
                        }
                        global.searchEditText = ""
                    }
                    ButtonGroup.group: global.siderGroup
                }
            }

            RowLayout{
                Layout.alignment: Qt.AlignCenter
                spacing: 100

                visible: albumControl.getDevicePaths(global.deviceChangeList).length>0 ?true :false
                Label {
                    id:deviceLabel
                    height: 30
                    text: qsTr("Device")
                    color: Qt.rgba(0,0,0,0.3)
                }
            }

            ListView{
                id : deviceList
                height:albumControl.getDevicePaths(global.deviceChangeList).length *42
                width:parent.width
                clip: true
                visible: true
                interactive: false //禁用原有的交互逻辑，重新开始定制

                model :albumControl.getDevicePaths(global.deviceChangeList).length
                delegate:    ItemDelegate {
                    text: albumControl.getDeviceNames(global.deviceChangeList)[index]
                    width: parent.width - 20
                    height : 36
                    icon.name: "item"
                    checked: index == 0
                    backgroundVisible: false
                    onClicked: {
//                            global.currentViewIndex = 6
//                            global.currentCustomAlbumUId = albumControl.getAllCustomAlbumId(global.albumChangeList)[index]
                    }
                    ButtonGroup.group: global.siderGroup
                }
            }

            RowLayout{
                Layout.alignment: Qt.AlignCenter
                spacing: 100
                Label {
                    id:albumLabel
                    height: 30
                    text: qsTr("Albums")
                    color: Qt.rgba(0,0,0,0.3)
                }

                FloatingButton {
                    id:addAlbumButton
                    checked: false
                    width: 20
                    height: 20

                    icon{
                        name: "add-xiangce"
                        width: 10
                        height: 10
                    }


                    onClicked: {
                        var x = parent.mapToGlobal(0, 0).x + parent.width / 2 - 190
                        var y = parent.mapToGlobal(0, 0).y + parent.height / 2 - 89
                        newAlbum.setX(x)
                        newAlbum.setY(y)

                        newAlbum.show()
                    }
                }
            }
            ListView{
                id : fixedList
                height:3 * 36
                width:parent.width
                clip: true
                visible: true
                interactive: false //禁用原有的交互逻辑，重新开始定制

                model: ListModel {
                    ListElement {
                        name: qsTr("Screen Capture")
                        number: "1"
                        iconName :"item"

                    }
                    ListElement {
                        name: qsTr("Camera")
                        number: "2"
                        iconName :"item"
                    }
                    ListElement {
                        name: qsTr("Draw")
                        number: "3"
                        iconName :"item"
                    }
                }
                delegate:    ItemDelegate {
                    text: name
                    width: parent.width - 20
                    height : 36
                    icon.name: iconName
                    checked: index == 0
                    backgroundVisible: false
                    onClicked: {
                        global.currentViewIndex = 6
                        global.currentCustomAlbumUId = number
                        global.searchEditText = ""
                    }
                    ButtonGroup.group: global.siderGroup
                }

            }

            ListView{
                id : customList
                height:albumControl.getAllCustomAlbumId(global.albumChangeList).length * 42
                width:parent.width
                clip: true
                visible: true
                interactive: false //禁用原有的交互逻辑，重新开始定制

                model :albumControl.getAllCustomAlbumId(global.albumChangeList).length
                delegate:    ItemDelegate {
                    text: albumControl.getAllCustomAlbumName()[index]
                    width: parent.width - 20
                    height : 36
                    icon.name: "item"
                    checked: index == 0
                    backgroundVisible: false
                    onClicked: {
                        global.currentViewIndex = 6
                        global.currentCustomAlbumUId = albumControl.getAllCustomAlbumId(global.albumChangeList)[index]

                    }
                    ButtonGroup.group: global.siderGroup
                }
            }
        }
        //rename窗口
        NewAlbumDialog {
            id: newAlbum
        }
    }
}
