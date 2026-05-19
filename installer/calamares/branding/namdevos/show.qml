import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation {
    id: presentation

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0d1117"

            Column {
                anchors.centerIn: parent
                spacing: 20

                Text {
                    text: "Welcome to namdevOS"
                    color: "#ffffff"
                    font.pixelSize: 32
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "A developer-focused Linux distribution"
                    color: "#00d2d3"
                    font.pixelSize: 18
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Installing... This may take a few minutes."
                    color: "#a0a0b0"
                    font.pixelSize: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0d1117"

            Column {
                anchors.centerIn: parent
                spacing: 15

                Text {
                    text: "Developer Ready"
                    color: "#e94560"
                    font.pixelSize: 28
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "Git, Python, build-essential pre-installed\nDocker available via Package Selector\nVS Code, Node.js one click away\nCustom terminal with JetBrains Mono font"
                    color: "#e0e0e0"
                    font.pixelSize: 14
                    lineHeight: 1.6
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    Slide {
        Rectangle {
            anchors.fill: parent
            color: "#0d1117"

            Column {
                anchors.centerIn: parent
                spacing: 15

                Text {
                    text: "Almost Done!"
                    color: "#00d2d3"
                    font.pixelSize: 28
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Text {
                    text: "After installation:\nRun 'namdevos-package-selector' to install more software\nPress Super+Space for app launcher\nCtrl+Alt+T opens terminal"
                    color: "#e0e0e0"
                    font.pixelSize: 14
                    lineHeight: 1.6
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
