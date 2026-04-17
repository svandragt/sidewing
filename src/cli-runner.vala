namespace Sidewing {
    public class CliRunner : Object {
        private LogService log_service;
        private SettingsStore settings_store;
        private VariablesStore variables_store;
        private PluginRunner plugin_runner;

        public CliRunner() {
            log_service = new LogService(false);
            settings_store = new SettingsStore();
            variables_store = new VariablesStore(log_service);
            plugin_runner = new PluginRunner(log_service, variables_store, settings_store);
        }

        public int run_plugin_command(string[] args) {
            if (args.length != 3) {
                print_run_usage(args[0]);
                return 2;
            }

            string plugin_argument = args[2];
            string? plugin_path = resolve_plugin_path(plugin_argument);
            if (plugin_path == null) {
                stderr.printf("Plugin not found: %s\n", plugin_argument);
                stderr.printf("Searched in %s\n", settings_store.plugins_dir);
                return 1;
            }

            var plugin = build_plugin_definition(plugin_path);
            var result = plugin_runner.run(plugin);

            if (result.stdout_text != "") {
                stdout.printf("%s", result.stdout_text);
                if (!result.stdout_text.has_suffix("\n")) {
                    stdout.putc('\n');
                }
            }

            if (result.stderr_text != "") {
                stderr.printf("%s", result.stderr_text);
                if (!result.stderr_text.has_suffix("\n")) {
                    stderr.putc('\n');
                }
            }

            return result.exit_code;
        }

        private void print_run_usage(string executable_name) {
            stdout.printf("Usage: %s run <plugin>\n", executable_name);
        }

        private string? resolve_plugin_path(string plugin_argument) {
            if (Path.is_absolute(plugin_argument) || plugin_argument.contains("/")) {
                if (FileUtils.test(plugin_argument, FileTest.EXISTS)) {
                    return plugin_argument;
                }

                return null;
            }

            string plugin_path = Path.build_filename(settings_store.plugins_dir, plugin_argument);
            if (FileUtils.test(plugin_path, FileTest.EXISTS)) {
                return plugin_path;
            }

            return null;
        }

        private PluginDefinition build_plugin_definition(string plugin_path) {
            string filename = Path.get_basename(plugin_path);
            var variable_definitions = variables_store.load_variable_definitions(plugin_path);
            variables_store.sync_sidecar(new PluginDefinition(
                plugin_path,
                filename,
                filename,
                60,
                variable_definitions
            ));

            return new PluginDefinition(
                plugin_path,
                filename,
                filename,
                60,
                variable_definitions
            );
        }
    }
}
