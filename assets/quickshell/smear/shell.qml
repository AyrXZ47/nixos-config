import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Capa transparente y click-through que dibuja una estela cuando el cursor
// salta de una ventana a otra (Super+flechas). El movimiento del cursor NO se
// lee desde aca (Wayland no expone la posicion global del puntero): la dibuja
// hypr/scripts/smear.sh, que escucha el socket de eventos de Hyprland y pasa
// los dos centros por IPC.
ShellRoot {
    id: root
    property real ax: -1
    property real ay: -1
    property real bx: -1
    property real by: -1
    property int burst: 0

    IpcHandler {
        target: "smear"
        function streak(x1: real, y1: real, x2: real, y2: real): void {
            root.ax = x1; root.ay = y1;
            root.bx = x2; root.by = y2;
            root.burst = root.burst + 1;
        }
    }

    PanelWindow {
        anchors { top: true; left: true; right: true; bottom: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "smear"
        mask: Region {}

        Rectangle {
            id: streak
            height: 7
            radius: 3.5
            color: "#ff2233"
            visible: root.bx >= 0
            x: root.ax
            y: root.ay - height / 2
            width: root.bx >= 0 ? Math.max(1, Math.hypot(root.bx - root.ax, root.by - root.ay)) : 1
            rotation: Math.atan2(root.by - root.ay, root.bx - root.ax) * 180 / Math.PI
            transformOrigin: Item.Left
            opacity: 0

            SequentialAnimation {
                id: anim
                NumberAnimation { target: streak; property: "opacity"; from: 0.0; to: 0.95; duration: 45 }
                NumberAnimation { target: streak; property: "opacity"; from: 0.95; to: 0.0; duration: 200 }
            }

            Connections {
                target: root
                function onBurstChanged() { anim.restart(); }
            }
        }
    }
}
