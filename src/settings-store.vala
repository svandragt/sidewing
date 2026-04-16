namespace Staba {
    public class SettingsStore : Object {
        public string config_dir { get; private set; }
        public string plugins_dir { get; private set; }
        public string? selected_monitor_id { get; set; }
        public int bar_height { get; set; default = 32; }

        public SettingsStore() {
            config_dir = Path.build_filename(Environment.get_user_config_dir(), "staba");
            plugins_dir = Path.build_filename(Environment.get_current_dir(), "examples", "plugins");
            selected_monitor_id = null;
        }
    }
}
