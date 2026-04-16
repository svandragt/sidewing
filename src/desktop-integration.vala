namespace Sidewing {
    public class DesktopIntegration : Object {
        private const string DESKTOP_FILENAME = "com.vandragt.sidewing.desktop";

        private LogService log_service;

        public DesktopIntegration(LogService log_service) {
            this.log_service = log_service;
        }

        public bool install_desktop_entry() {
            try {
                write_desktop_entry(get_desktop_entry_path(), false);
                log_service.info(@"Installed desktop entry at $(get_desktop_entry_path())");
                return true;
            } catch (Error err) {
                log_service.warning(@"Failed to install desktop entry: $(err.message)");
                return false;
            }
        }

        public bool enable_autostart() {
            try {
                write_desktop_entry(get_desktop_entry_path(), false);
                write_desktop_entry(get_autostart_entry_path(), true);
                log_service.info(@"Enabled autostart at $(get_autostart_entry_path())");
                return true;
            } catch (Error err) {
                log_service.warning(@"Failed to enable autostart: $(err.message)");
                return false;
            }
        }

        public bool disable_autostart() {
            string autostart_path = get_autostart_entry_path();
            if (!FileUtils.test(autostart_path, FileTest.EXISTS)) {
                return true;
            }

            try {
                File.new_for_path(autostart_path).delete();
                log_service.info(@"Disabled autostart at $autostart_path");
                return true;
            } catch (Error err) {
                log_service.warning(@"Failed to disable autostart: $(err.message)");
                return false;
            }
        }

        public bool is_autostart_enabled() {
            return FileUtils.test(get_autostart_entry_path(), FileTest.EXISTS);
        }

        public string get_desktop_entry_path() {
            return Path.build_filename(
                Environment.get_user_data_dir(),
                "applications",
                DESKTOP_FILENAME
            );
        }

        public string get_autostart_entry_path() {
            return Path.build_filename(
                Environment.get_user_config_dir(),
                "autostart",
                DESKTOP_FILENAME
            );
        }

        private void write_desktop_entry(string path, bool autostart) throws Error {
            string directory = Path.get_dirname(path);
            DirUtils.create_with_parents(directory, 0755);

            string content = build_desktop_entry(autostart);
            FileUtils.set_contents(path, content);
        }

        private string build_desktop_entry(bool autostart) throws Error {
            string executable_path = resolve_executable_path();
            string exec_line = quote_exec_arg(executable_path);

            var builder = new StringBuilder();
            builder.append("[Desktop Entry]\n");
            builder.append("Type=Application\n");
            builder.append("Version=1.0\n");
            builder.append("Name=Sidewing\n");
            builder.append("Comment=GTK4 scriptable desktop bar for multi-monitor Linux setups\n");
            builder.append(@"Exec=$exec_line\n");
            builder.append("Terminal=false\n");
            builder.append("Categories=Utility;\n");
            builder.append("StartupNotify=false\n");
            builder.append("X-GNOME-UsesNotifications=false\n");

            if (autostart) {
                builder.append("X-GNOME-Autostart-enabled=true\n");
            }

            return builder.str;
        }

        private string resolve_executable_path() throws Error {
            string path = FileUtils.read_link("/proc/self/exe");
            if (path == null || path == "") {
                throw new FileError.INVAL("Unable to resolve current executable path");
            }

            return path;
        }

        private string quote_exec_arg(string value) {
            return "\"" + value.replace("\\", "\\\\").replace("\"", "\\\"") + "\"";
        }
    }
}
