{ pkgs, ... }:

let
  # MPRIS falso de Mixxx: Mixxx 2.5.6 no expone org.mpris.MediaPlayer2.mixxx
  # (verificado: sin bus, sin strings en el binario, sin bridge mantenido). En
  # vez de parchearlo, publicamos nosotros el servicio en el bus de sesion con
  # las interfaces estandar para que Caelestia lo vea como reproductor activo:
  # logo de Mixxx (mpris:artUrl) y bongocat (isPlaying) en el dashboard.
  #
  # ponytail: techo conocido = heuristica de PipeWire. El estado se deduce del
  # state del nodo Stream/Output/Audio cuyo nombre contenga "mixxx" (el wrapper
  # de common-packages lo expone como "PipeWire ALSA [.mixxx-wrapped]"); no hay
  # metadatos de pista porque Mixxx no los publica, y los metodos de control son
  # no-op porque Mixxx no tiene API remota. Solo lectura (pw-dump), sin tocar el
  # audio. Si algun dia Mixxx expone MPRIS nativo, borrar este modulo.
  mixxxMpris = pkgs.writers.writePython3Bin "mixxx-mpris" {
    libraries = [ pkgs.python3Packages.pydbus pkgs.python3Packages.pygobject3 ];
  } ''
    import json
    import subprocess

    import pydbus
    from pydbus.generic import signal
    from gi.repository import GLib

    BUS_NAME = "org.mpris.MediaPlayer2.mixxx"
    OBJECT_PATH = "/org/mpris/MediaPlayer2"
    TRACK_ID = "/org/mpris/MediaPlayer2/mixxx"
    ART_URL = (
        "file:///run/current-system/sw/share/icons/hicolor/256x256/apps/mixxx.png"
    )

    NODE_XML = """
    <node>
      <interface name="org.mpris.MediaPlayer2">
        <property name="CanQuit" type="b" access="read"/>
        <property name="CanRaise" type="b" access="read"/>
        <property name="HasTrackList" type="b" access="read"/>
        <property name="Identity" type="s" access="read"/>
        <property name="DesktopEntry" type="s" access="read"/>
        <property name="SupportedUriSchemes" type="as" access="read"/>
        <property name="SupportedMimeTypes" type="as" access="read"/>
      </interface>
      <interface name="org.mpris.MediaPlayer2.Player">
        <method name="Next"/>
        <method name="Previous"/>
        <method name="Pause"/>
        <method name="PlayPause"/>
        <method name="Stop"/>
        <method name="Play"/>
        <method name="Seek">
          <arg name="Offset" type="x" direction="in"/>
        </method>
        <method name="SetPosition">
          <arg name="TrackId" type="o" direction="in"/>
          <arg name="Position" type="x" direction="in"/>
        </method>
        <method name="OpenUri">
          <arg name="Uri" type="s" direction="in"/>
        </method>
        <property name="PlaybackStatus" type="s" access="read"/>
        <property name="LoopStatus" type="s" access="readwrite"/>
        <property name="Rate" type="d" access="readwrite"/>
        <property name="Shuffle" type="b" access="readwrite"/>
        <property name="Metadata" type="a{sv}" access="read"/>
        <property name="Volume" type="d" access="readwrite"/>
        <property name="Position" type="x" access="read"/>
        <property name="MinimumRate" type="d" access="read"/>
        <property name="MaximumRate" type="d" access="read"/>
        <property name="CanGoNext" type="b" access="read"/>
        <property name="CanGoPrevious" type="b" access="read"/>
        <property name="CanPlay" type="b" access="read"/>
        <property name="CanPause" type="b" access="read"/>
        <property name="CanSeek" type="b" access="read"/>
        <property name="CanControl" type="b" access="read"/>
      </interface>
    </node>
    """


    class MixxxMpris:
        # pydbus lee el XML de introspeccion de __doc__ (no de un docstring).
        __doc__ = NODE_XML

        # pydbus engancha esta senal a org.freedesktop.DBus.Properties.
        PropertiesChanged = signal()

        Identity = "Mixxx"
        DesktopEntry = "org.mixxx.Mixxx"
        CanQuit = False
        CanRaise = False
        HasTrackList = False
        SupportedUriSchemes = []
        SupportedMimeTypes = []

        LoopStatus = "None"
        Rate = 1.0
        Shuffle = False
        Volume = 1.0
        Position = 0
        MinimumRate = 1.0
        MaximumRate = 1.0
        CanGoNext = False
        CanGoPrevious = False
        CanPlay = True
        CanPause = True
        CanSeek = False
        CanControl = True

        def __init__(self):
            self._status = "Stopped"

        @property
        def PlaybackStatus(self):
            return self._status

        @property
        def Metadata(self):
            return {
                "mpris:trackid": GLib.Variant("o", TRACK_ID),
                "xesam:title": GLib.Variant("s", "Mixxx"),
                "mpris:artUrl": GLib.Variant("s", ART_URL),
            }

        # Mixxx no tiene API de control remoto: no-op para que los botones de
        # Caelestia no revienten.
        def Next(self):
            pass

        def Previous(self):
            pass

        def Pause(self):
            pass

        def PlayPause(self):
            pass

        def Stop(self):
            pass

        def Play(self):
            pass

        def Seek(self, Offset):
            pass

        def SetPosition(self, TrackId, Position):
            pass

        def OpenUri(self, Uri):
            pass

        def set_status(self, status):
            if status != self._status:
                self._status = status
                self.PropertiesChanged(
                    "org.mpris.MediaPlayer2.Player",
                    {"PlaybackStatus": status},
                    [],
                )


    def mixxx_states():
        try:
            raw = subprocess.run(
                ["pw-dump"],
                capture_output=True,
                text=True,
                timeout=5,
                check=True,
            ).stdout
            objects = json.loads(raw)
        except Exception:
            return []
        states = []
        for obj in objects:
            if obj.get("type") != "PipeWire:Interface:Node":
                continue
            props = (obj.get("info") or {}).get("props") or {}
            if "Output/Audio" not in str(props.get("media.class", "")):
                continue
            names = (
                props.get("application.name"),
                props.get("application.process.binary"),
                props.get("node.name"),
                props.get("node.description"),
            )
            if any("mixxx" in str(name).lower() for name in names):
                states.append((obj.get("info") or {}).get("state"))
        return states


    def poll(player):
        states = mixxx_states()
        if not states:
            status = "Stopped"
        elif any(state == "running" for state in states):
            status = "Playing"
        else:
            status = "Paused"
        player.set_status(status)
        return True


    def main():
        bus = pydbus.SessionBus()
        player = MixxxMpris()
        bus.publish(BUS_NAME, (OBJECT_PATH, player))
        poll(player)
        GLib.timeout_add_seconds(1, poll, player)
        GLib.MainLoop().run()


    if __name__ == "__main__":
        main()
  '';
in
{
  home.packages = [ mixxxMpris ];

  systemd.user.services.mixxx-mpris = {
    Unit.Description = "MPRIS falso de Mixxx (org.mpris.MediaPlayer2.mixxx)";
    Service = {
      ExecStart = "${mixxxMpris}/bin/mixxx-mpris";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
