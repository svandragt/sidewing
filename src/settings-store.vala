namespace Sidewing {
    public class SettingsStore : Object {
        public string config_dir { get; private set; }
        public string config_path { get; private set; }
        public string data_dir { get; private set; }
        public string plugins_dir { get; private set; }
        public string? selected_monitor_id { get; set; }
        public int bar_height { get; set; default = 32; }

        public SettingsStore() {
            config_dir = Path.build_filename(Environment.get_user_config_dir(), "sidewing");
            config_path = Path.build_filename(config_dir, "config.ini");
            data_dir = Path.build_filename(Environment.get_user_data_dir(), "sidewing");
            plugins_dir = Path.build_filename(data_dir, "plugins");
            selected_monitor_id = null;
            load();
        }

        public void update_selected_monitor_id(string? monitor_id) {
            selected_monitor_id = monitor_id;
            save();
        }

        public void update_plugins_dir(string plugins_dir) {
            this.plugins_dir = plugins_dir;
            save();
        }

        public void update_bar_height(int bar_height) {
            this.bar_height = bar_height;
            save();
        }

        public void load() {
            var key_file = new KeyFile();
            bool should_resave = false;

            try {
                key_file.load_from_file(config_path, KeyFileFlags.NONE);

                if (key_file.has_key("general", "plugins_dir")) {
                    plugins_dir = key_file.get_string("general", "plugins_dir");
                }

                if (key_file.has_key("general", "selected_monitor_id")) {
                    selected_monitor_id = key_file.get_string("general", "selected_monitor_id");
                }

                if (key_file.has_key("general", "bar_height")) {
                    bar_height = key_file.get_integer("general", "bar_height");
                }
            } catch (FileError err) {
                // Missing config file is expected on first launch.
            } catch (Error err) {
                warning("Failed to load settings: %s", err.message);
            }

            string legacy_source_plugins_dir = Path.build_filename(Build.PROJECT_SOURCE_ROOT, "examples", "plugins");
            if (plugins_dir == "" || plugins_dir == legacy_source_plugins_dir) {
                plugins_dir = Path.build_filename(data_dir, "plugins");
                should_resave = true;
            }

            if (bar_height < 24) {
                bar_height = 24;
                should_resave = true;
            }

            if (should_resave) {
                save();
            }
        }

        public bool save() {
            try {
                DirUtils.create_with_parents(config_dir, 0755);
                DirUtils.create_with_parents(data_dir, 0755);

                var key_file = new KeyFile();
                key_file.set_string("general", "plugins_dir", plugins_dir);
                key_file.set_integer("general", "bar_height", bar_height);

                if (selected_monitor_id != null && selected_monitor_id != "") {
                    key_file.set_string("general", "selected_monitor_id", selected_monitor_id);
                }

                size_t length = 0;
                string data = key_file.to_data(out length);
                FileUtils.set_contents(config_path, data, (ssize_t) length);
                return true;
            } catch (Error err) {
                warning("Failed to save settings: %s", err.message);
                return false;
            }
        }

        public void ensure_plugins_dir_seeded(LogService log_service) {
            DirUtils.create_with_parents(plugins_dir, 0755);

            if (!directory_is_empty(plugins_dir)) {
                return;
            }

            string bundled_examples_dir = Path.build_filename(Build.PROJECT_SOURCE_ROOT, "examples", "plugins");
            var source_dir = File.new_for_path(bundled_examples_dir);
            var target_dir = File.new_for_path(plugins_dir);

            try {
                var enumerator = source_dir.enumerate_children(
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
                    var source_child = source_dir.get_child(filename);
                    var target_child = target_dir.get_child(filename);

                    source_child.copy(
                        target_child,
                        FileCopyFlags.OVERWRITE | FileCopyFlags.ALL_METADATA,
                        null,
                        null
                    );
                }

                log_service.info(@"Seeded onboarding plugins into $(plugins_dir)");
            } catch (Error err) {
                log_service.warning(@"Failed to seed onboarding plugins: $(err.message)");
            }
        }

        private bool directory_is_empty(string path) {
            try {
                var directory = File.new_for_path(path);
                var enumerator = directory.enumerate_children(
                    FileAttribute.STANDARD_NAME,
                    FileQueryInfoFlags.NONE
                );

                return enumerator.next_file() == null;
            } catch (Error err) {
                return true;
            }
        }
    }
}
