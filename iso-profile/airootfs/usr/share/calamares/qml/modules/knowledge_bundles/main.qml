import QtQuick 2.0
import QtQuick.Controls 2.0
import calamares.viewsteps 1.1

ViewStep {
    id: knowledgeBundlesPage
    title: "Synchronize Knowledge Bundles"

    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 15

        Text {
            text: "Select software packages to synchronize with your holocron:"
            color: "#f3dfb4"
            font.pixelSize: 16
        }

        CheckBox {
            id: codingBundle
            text: "[Jedi Sentinel] Dev Suite (Git, Docker, VS Code, etc.)"
            checked: true
            onCheckedChanged: branding.setGlobalString("bundle_coding", checked ? "true" : "false")
        }

        CheckBox {
            id: gamingBundle
            text: "[Podracing] Gaming Bundle (Steam, Lutris, Gamemode)"
            onCheckedChanged: branding.setGlobalString("bundle_gaming", checked ? "true" : "false")
        }

        CheckBox {
            id: mediaBundle
            text: "[Archives] Media/Office (VLC, LibreOffice)"
            onCheckedChanged: branding.setGlobalString("bundle_media", checked ? "true" : "false")
        }
    }

    function onActivate() {
        branding.setGlobalString("bundle_coding", "true")
        branding.setGlobalString("bundle_gaming", "false")
        branding.setGlobalString("bundle_media", "false")
    }
}
