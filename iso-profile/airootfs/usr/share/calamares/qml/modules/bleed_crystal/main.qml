import QtQuick 2.0
import QtQuick.Controls 2.0
import calamares.viewsteps 1.1

ViewStep {
    id: bleedCrystalPage
    title: "Bleeding the Crystal"

    Column {
        anchors.centerIn: parent
        spacing: 20

        Text {
            text: "Would you like to compile a custom kernel from source?"
            color: "#f3dfb4"
            font.pixelSize: 18
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            text: "This requires immense focus and many cycles (time-consuming)."
            color: "#7d812c"
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
        }

        Switch {
            id: bleedSwitch
            text: "Bleed the Crystal"
            anchors.horizontalCenter: parent
            onCheckedChanged: branding.setGlobalString("bleed_crystal", checked ? "true" : "false")
        }
    }

    function onActivate() {
        branding.setGlobalString("bleed_crystal", "false")
    }
}
