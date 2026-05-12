import QtQuick 2.0
import QtQuick.Controls 2.0
import calamares.viewsteps 1.1

ViewStep {
    id: sideSelectionPage
    title: "Choose Your Path"

    property string selectedSide: "jedi"

    Column {
        anchors.centerIn: parent
        spacing: 20

        Text {
            text: "The Force is calling. Which path will you follow?"
            color: "#f3dfb4"
            font.pixelSize: 18
            font.bold: true
        }

        Row {
            spacing: 40
            anchors.horizontalCenter: parent

            Button {
                text: "The Light Side (Jedi)"
                width: 200
                height: 100
                onClicked: {
                    selectedSide = "jedi"
                    branding.setGlobalString("force_path", "jedi")
                    // Hack to pass variable to shellprocess
                    var process = Qt.createQmlObject('import QtQuick 2.0; Timer { interval: 100; running: true; onTriggered: { var file = "/tmp/calamares_force_path"; var xhr = new XMLHttpRequest(); xhr.open("PUT", "file://" + file); xhr.send("jedi"); } }', parent);
                }
                background: Rectangle {
                    color: selectedSide === "jedi" ? "#00D4FF" : "#1A1B26"
                    border.color: "#00D4FF"
                    radius: 10
                }
            }

            Button {
                text: "The Dark Side (Sith)"
                width: 200
                height: 100
                onClicked: {
                    selectedSide = "sith"
                    branding.setGlobalString("force_path", "sith")
                    var process = Qt.createQmlObject('import QtQuick 2.0; Timer { interval: 100; running: true; onTriggered: { var file = "/tmp/calamares_force_path"; var xhr = new XMLHttpRequest(); xhr.open("PUT", "file://" + file); xhr.send("sith"); } }', parent);
                }
                background: Rectangle {
                    color: selectedSide === "sith" ? "#FF0000" : "#1A1B26"
                    border.color: "#FF0000"
                    radius: 10
                }
            }
        }
    }

    function onActivate() {
        branding.setGlobalString("force_path", "jedi")
    }
}
