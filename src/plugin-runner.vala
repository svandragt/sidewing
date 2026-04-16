namespace Sidewing {
    public class PluginRunner : Object {
        private LogService log_service;
        private VariablesStore variables_store;
        private SettingsStore settings_store;

        public PluginRunner(LogService log_service, VariablesStore variables_store, SettingsStore settings_store) {
            this.log_service = log_service;
            this.variables_store = variables_store;
            this.settings_store = settings_store;
        }

        public PluginRunResult run(PluginDefinition plugin) {
            log_service.info(@"Running plugin $(plugin.filename)");

            try {
                var launcher = new SubprocessLauncher(SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                string plugin_dir = Path.get_dirname(plugin.path);

                launcher.set_cwd(plugin_dir);
                launcher.setenv("STABA", "1", true);
                launcher.setenv("XBAR", "1", true);
                launcher.setenv("STABA_PLUGIN_PATH", plugin.path, true);
                launcher.setenv("STABA_PLUGIN_DIR", settings_store.plugins_dir, true);
                variables_store.apply_to_launcher(launcher, plugin);

                string[] argv = { plugin.path, null };
                var process = launcher.spawnv(argv);

                string? stdout_text = null;
                string? stderr_text = null;
                process.communicate_utf8(null, null, out stdout_text, out stderr_text);

                return new PluginRunResult(
                    stdout_text ?? "",
                    stderr_text ?? "",
                    process.get_exit_status(),
                    false
                );
            } catch (Error err) {
                log_service.warning(@"Plugin run failed for $(plugin.filename): $(err.message)");
                return new PluginRunResult(
                    "",
                    err.message,
                    1,
                    false,
                    err.message.contains("No such file or directory")
                );
            }
        }
    }
}
