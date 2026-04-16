namespace Staba {
    public class PluginManager : Object {
        private SettingsStore settings_store;
        private PluginRunner plugin_runner;
        private XbarParser xbar_parser;
        private LogService log_service;

        public PluginManager(
            SettingsStore settings_store,
            PluginRunner plugin_runner,
            XbarParser xbar_parser,
            LogService log_service
        ) {
            this.settings_store = settings_store;
            this.plugin_runner = plugin_runner;
            this.xbar_parser = xbar_parser;
            this.log_service = log_service;
        }

        public Gee.ArrayList<PluginDefinition> discover_plugins() {
            var plugins = new Gee.ArrayList<PluginDefinition>();
            var directory = File.new_for_path(settings_store.plugins_dir);

            try {
                var enumerator = directory.enumerate_children(
                    FileAttribute.STANDARD_NAME + "," +
                    FileAttribute.STANDARD_TYPE + "," +
                    FileAttribute.UNIX_MODE,
                    FileQueryInfoFlags.NONE
                );

                FileInfo? info;
                while ((info = enumerator.next_file()) != null) {
                    if (info.get_file_type() != FileType.REGULAR) {
                        continue;
                    }

                    string filename = info.get_name();
                    uint refresh_seconds = parse_refresh_seconds(filename);
                    if (refresh_seconds == 0) {
                        continue;
                    }

                    var child = directory.get_child(filename);
                    plugins.add(new PluginDefinition(
                        child.get_path(),
                        filename,
                        filename,
                        refresh_seconds
                    ));
                }
            } catch (Error err) {
                log_service.warning(@"Plugin discovery failed: $(err.message)");
            }

            return plugins;
        }

        private uint parse_refresh_seconds(string filename) {
            try {
                var regex = new Regex(""".*\.([0-9]+)([smhd])\.[^.]+$""");
                MatchInfo info;
                if (!regex.match(filename, 0, out info)) {
                    return 0;
                }

                uint value = uint.parse(info.fetch(1));
                switch (info.fetch(2)) {
                case "s":
                    return value;
                case "m":
                    return value * 60;
                case "h":
                    return value * 60 * 60;
                case "d":
                    return value * 60 * 60 * 24;
                default:
                    return 0;
                }
            } catch (Error err) {
                log_service.warning(@"Failed to parse plugin interval: $(err.message)");
                return 0;
            }
        }
    }
}
