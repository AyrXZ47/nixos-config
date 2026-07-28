{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [ mpd ncmpcpp ];

  xdg.configFile."mpd/mpd.conf".text = ''
    auto_update    "yes"
    restore_paused "yes"
    playlist_directory "~/.config/mpd/playlists"
    db_file            "~/.config/mpd/database"
    pid_file           "~/.config/mpd/pid"
    state_file         "~/.config/mpd/state"
  '';

  xdg.configFile."ncmpcpp/config".text = ''
    visualizer_data_source = "/tmp/mpd.fifo"
    visualizer_output_name = "my_fifo"
    visualizer_in_stereo = "yes"
    visualizer_type = "spectrum"
    visualizer_look = "◆▋"
    message_delay_time = "3"
    playlist_shorten_total_times = "yes"
    playlist_display_mode = "columns"
    browser_display_mode = "columns"
    autocenter_mode = "yes"
    centered_cursor = "yes"
  '';
}
