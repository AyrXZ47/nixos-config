{ pkgs, ... }:

let
  # MPRIS falso de Mixxx: Mixxx 2.5.6 no expone org.mpris.MediaPlayer2.mixxx
  # (verificado: sin bus, sin strings en el binario, sin bridge mantenido). En
  # vez de parchearlo, publicamos nosotros el servicio en el bus de sesion con
  # las interfaces estandar para que Caelestia lo vea como reproductor activo:
  # logo de Mixxx (mpris:artUrl) y bongocat (isPlaying) en el dashboard.
  #
  # Titulo/artista reales: Mixxx escribe "<Artist> - <Title> | Mixxx" en el
  # titulo de su ventana (mixxxmainwindow.cpp: slotUpdateWindowTitle) y la barra
  # de Caelestia pinta ese mismo dato (Hypr.activeToplevel.title). Se reusa
  # (via `hyprctl -j clients`) para que el panel de media muestre la pista.
  #
  # ponytail: techo conocido = heuristica de PipeWire + scraping del titulo de
  # ventana. El estado se deduce del state del nodo Stream/Output/Audio cuyo
  # nombre contenga "mixxx" (el wrapper de common-packages lo expone como
  # "PipeWire ALSA [.mixxx-wrapped]"); el titulo solo aparece cuando Mixxx lo
  # actualiza (pista cargada/reproduciendose). Los metodos de control son no-op
  # porque Mixxx 2.5.6 no tiene API remota. Solo lectura (pw-dump + hyprctl);
  # sin tocar el audio. Si algun dia Mixxx expone MPRIS nativo (PR upstream
  # #15754), borrar este modulo.
  mixxxMpris = pkgs.writers.writePython3Bin "mixxx-mpris" {
    libraries = [ pkgs.python3Packages.pydbus pkgs.python3Packages.pygobject3 ];
  } ''
    import json
    import subprocess
    import urllib.parse
    import urllib.request

    import pydbus
    from pydbus.generic import signal
    from gi.repository import GLib

    BUS_NAME = "org.mpris.MediaPlayer2.mixxx"
    OBJECT_PATH = "/org/mpris/MediaPlayer2"
    TRACK_ID = "/org/mpris/MediaPlayer2/mixxx"
    ART_URL = (
        "file:///run/current-system/sw/share/icons/hicolor/256x256/apps/mixxx.png"
    )

    # Duración "desconocida" en microsegundos: > INT_MAX segundos, el umbral con
    # el que Caelestia omite `duration` al pedir letras (y pinta "--:--").
    UNKNOWN_LENGTH_US = 2147483648 * 1_000_000

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
            self._title = "Mixxx"
            self._artist = ""
            self._album = ""
            self._length = UNKNOWN_LENGTH_US
            self._raw = None

        @property
        def PlaybackStatus(self):
            return self._status

        @property
        def Metadata(self):
            metadata = {
                "mpris:trackid": GLib.Variant("o", TRACK_ID),
                "xesam:title": GLib.Variant("s", self._title),
                "mpris:artUrl": GLib.Variant("s", ART_URL),
                # Sin mpris:length, Quickshell reporta `length` = posición y
                # Caelestia manda una duración falsa -> lrclib /get da 404.
                "mpris:length": GLib.Variant("x", self._length),
            }
            if self._artist:
                metadata["xesam:artist"] = GLib.Variant("as", [self._artist])
            if self._album:
                metadata["xesam:album"] = GLib.Variant("s", self._album)
            return metadata

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

        def set_metadata(self, title, artist, album="", length=UNKNOWN_LENGTH_US):
            if (title, artist, album, length) != (
                self._title,
                self._artist,
                self._album,
                self._length,
            ):
                self._title = title
                self._artist = artist
                self._album = album
                self._length = length
                self.PropertiesChanged(
                    "org.mpris.MediaPlayer2.Player",
                    {"Metadata": self.Metadata},
                    [],
                )

        def update_track(self, raw):
            # Cachea por título crudo: una búsqueda en lrclib por pista, no por
            # cada tick del poll.
            if raw == self._raw:
                return
            self._raw = raw
            if not raw:
                self.set_metadata("Mixxx", "")
                return
            title, artist = split_track(raw)
            canon = lrclib_lookup(title, artist)
            if canon:
                self.set_metadata(*canon)
            else:
                self.set_metadata(title, artist)


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


    def mixxx_window_title():
        # Título de la ventana de Mixxx ("Artist - Title | Mixxx"), el mismo
        # dato que pinta la barra de Caelestia. Se busca por clase y no por
        # ventana activa: funciona aunque Mixxx no tenga el foco.
        try:
            raw = subprocess.run(
                ["hyprctl", "-j", "clients"],
                capture_output=True,
                text=True,
                timeout=5,
                check=True,
            ).stdout
            clients = json.loads(raw)
        except Exception:
            return None
        for client in clients:
            if client.get("class") == "org.mixxx.Mixxx":
                return client.get("title") or None
        return None


    def split_track(raw):
        # "Artist - Title | Mixxx" -> ("Title", "Artist"); sin separador,
        # ("<lo que haya>", ""). Se corta el sufijo " | Mixxx" por la derecha.
        track = raw.rsplit(" | ", 1)[0].strip()
        if " - " in track:
            artist, _, name = track.partition(" - ")
            return name.strip(), artist.strip()
        return track, ""


    def lrclib_lookup(title, artist):
        # ponytail: techo conocido = una petición HTTPS a lrclib por cambio de
        # pista (cacheada por título crudo). Necesaria porque Mixxx no expone
        # tags canónicos ni duración: sin esto Caelestia pide lrclib /get con el
        # artista scrapeado y una duración falsa, y da 404 siempre. Devuelve
        # (title, artist, album, length_us) canónicos, o None si no hay match.
        params = {"track_name": title}
        if artist:
            params["artist_name"] = artist
        url = "https://lrclib.net/api/search?" + urllib.parse.urlencode(params)
        req = urllib.request.Request(url, headers={"User-Agent": "mixxx-mpris"})
        try:
            with urllib.request.urlopen(req, timeout=5) as resp:
                results = json.load(resp)
        except Exception:
            return None
        if not isinstance(results, list) or not results:
            return None

        # Caelestia solo carga letra SINCRONIZADA de lrclib; priorízala.
        best = next((x for x in results if x.get("syncedLyrics")), results[0])
        duration = best.get("duration")
        length_us = (
            int(round(duration * 1_000_000))
            if isinstance(duration, (int, float)) and duration > 0
            else UNKNOWN_LENGTH_US
        )
        return (
            best.get("trackName") or title,
            best.get("artistName") or artist,
            best.get("albumName") or "",
            length_us,
        )


    def poll(player):
        states = mixxx_states()
        if not states:
            status = "Stopped"
        elif any(state == "running" for state in states):
            status = "Playing"
        else:
            status = "Paused"
        player.set_status(status)
        player.update_track(mixxx_window_title())
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
      Environment = [ "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt" ];
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
