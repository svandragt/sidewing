namespace Sidewing {
    public class DesktopIntegration : Object {
        private const string DESKTOP_FILENAME = "com.vandragt.sidewing.desktop";
        private const string SYSTEMD_UNIT_FILENAME = "sidewing.service";

        private LogService log_service;

        public DesktopIntegration(LogService log_service) {
            this.log_service = log_service;
        }

        public bool enable_autostart() {
            if (systemd_user_available()) {
                return enable_autostart_systemd();
            }
            return enable_autostart_xdg();
        }

        public bool disable_autostart() {
            bool ok = true;
            if (systemd_unit_installed()) {
                ok = disable_autostart_systemd() && ok;
            }
            if (FileUtils.test(get_autostart_entry_path(), FileTest.EXISTS)) {
                ok = disable_autostart_xdg() && ok;
            }
            return ok;
        }

        public bool is_autostart_enabled() {
            if (systemd_unit_installed() && systemctl_is_enabled()) {
                return true;
            }
            return FileUtils.test(get_autostart_entry_path(), FileTest.EXISTS);
        }

        public string get_autostart_entry_path() {
            return Path.build_filename(
                Environment.get_user_config_dir(),
                "autostart",
                DESKTOP_FILENAME
            );
        }

        public string get_systemd_unit_path() {
            return Path.build_filename(
                Environment.get_user_config_dir(),
                "systemd",
                "user",
                SYSTEMD_UNIT_FILENAME
            );
        }

        private bool enable_autostart_systemd() {
            try {
                write_systemd_unit();
            } catch (Error err) {
                log_service.warning(@"Failed to write systemd unit, falling back to XDG autostart: $(err.message)");
                return enable_autostart_xdg();
            }

            if (!run_systemctl({"daemon-reload"})
                || !run_systemctl({"enable", "--now", SYSTEMD_UNIT_FILENAME})) {
                log_service.warning("systemctl enable failed, falling back to XDG autostart");
                return enable_autostart_xdg();
            }

            // Remove XDG autostart if previously set — systemd unit supersedes it.
            string xdg_path = get_autostart_entry_path();
            if (FileUtils.test(xdg_path, FileTest.EXISTS)) {
                try {
                    File.new_for_path(xdg_path).delete();
                } catch (Error err) {
                    log_service.warning(@"Failed to remove stale XDG autostart: $(err.message)");
                }
            }

            log_service.info(@"Enabled autostart via systemd unit $(get_systemd_unit_path())");
            return true;
        }

        private bool disable_autostart_systemd() {
            if (!run_systemctl({"disable", SYSTEMD_UNIT_FILENAME})) {
                log_service.warning("systemctl disable failed");
                return false;
            }
            log_service.info("Disabled autostart via systemd");
            return true;
        }

        private bool enable_autostart_xdg() {
            try {
                write_desktop_entry(get_autostart_entry_path(), true);
                log_service.info(@"Enabled autostart at $(get_autostart_entry_path())");
                return true;
            } catch (Error err) {
                log_service.warning(@"Failed to enable autostart: $(err.message)");
                return false;
            }
        }

        private bool disable_autostart_xdg() {
            string autostart_path = get_autostart_entry_path();
            try {
                File.new_for_path(autostart_path).delete();
                log_service.info(@"Disabled autostart at $autostart_path");
                return true;
            } catch (Error err) {
                log_service.warning(@"Failed to disable autostart: $(err.message)");
                return false;
            }
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

        private void write_systemd_unit() throws Error {
            string path = get_systemd_unit_path();
            DirUtils.create_with_parents(Path.get_dirname(path), 0755);

            string executable_path = resolve_executable_path();
            string exec_line = quote_exec_arg(executable_path);

            var builder = new StringBuilder();
            builder.append("[Unit]\n");
            builder.append("Description=Sidewing desktop bar\n");
            builder.append("PartOf=graphical-session.target\n");
            builder.append("After=graphical-session.target\n");
            builder.append("StartLimitIntervalSec=60\n");
            builder.append("StartLimitBurst=5\n");
            builder.append("\n");
            builder.append("[Service]\n");
            builder.append("Type=simple\n");
            builder.append(@"ExecStart=$exec_line\n");
            builder.append("Restart=on-failure\n");
            builder.append("RestartSec=3\n");
            builder.append("StandardOutput=journal\n");
            builder.append("StandardError=journal\n");
            builder.append("SyslogIdentifier=sidewing\n");
            builder.append("\n");
            builder.append("[Install]\n");
            builder.append("WantedBy=graphical-session.target\n");

            FileUtils.set_contents(path, builder.str);
        }

        private bool systemd_unit_installed() {
            return FileUtils.test(get_systemd_unit_path(), FileTest.EXISTS);
        }

        private bool systemd_user_available() {
            return run_systemctl({"--version"});
        }

        private bool systemctl_is_enabled() {
            return run_systemctl({"is-enabled", "--quiet", SYSTEMD_UNIT_FILENAME});
        }

        private bool run_systemctl(string[] extra_args) {
            string[] argv = { "systemctl", "--user" };
            foreach (string arg in extra_args) {
                argv += arg;
            }

            try {
                int exit_status;
                Process.spawn_sync(
                    null,
                    argv,
                    null,
                    SpawnFlags.SEARCH_PATH | SpawnFlags.STDOUT_TO_DEV_NULL | SpawnFlags.STDERR_TO_DEV_NULL,
                    null,
                    null,
                    null,
                    out exit_status
                );
                return Process.check_exit_status(exit_status);
            } catch (Error err) {
                return false;
            }
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
