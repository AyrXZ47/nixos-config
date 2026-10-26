{ ... }:

{
  # Raiz btrfs en SSD/NVMe: TRIM continuo por la via del filesystem.
  # `discard=async` (btrfs >= 5.6) encola los descartes y los manda en tandas:
  # no bloquea la escritura como el `discard` sincronico de ext4 y no depende
  # de un timer que haga catch-up en el primer arranque del dia.
  # Se importa SOLO desde pc y laptop (server y vm son ext4).
  fileSystems."/".options = [ "discard=async" ];
}
