namespace Staba {
    public class PluginRunner : Object {
        private LogService log_service;
        private VariablesStore variables_store;
        private SettingsStore settings_store;

        public PluginRunner(LogService log_service, VariablesStore variables_store, SettingsStore settings_store) {
            this.log_service = log_service;
            this.variables_store = variables_store;
            this.settings_store = settings_store;
        }

        public PluginRunResult run_placeholder(PluginDefinition plugin) {
            log_service.info(@"Placeholder run for $(plugin.filename)");
            return new PluginRunResult("staba", "", 0, false);
        }
    }
}
