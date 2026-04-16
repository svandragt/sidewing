namespace Staba {
    public class Application : Gtk.Application {
        private SettingsStore settings_store;
        private VariablesStore variables_store;
        private LogService log_service;
        private MonitorManager monitor_manager;
        private PluginRunner plugin_runner;
        private XbarParser xbar_parser;
        private PluginManager plugin_manager;
        private ActionDispatcher action_dispatcher;
        private MenuBuilder menu_builder;
        private BarWindow? bar_window;

        public Application() {
            Object(
                application_id: "io.elementary.staba",
                flags: ApplicationFlags.DEFAULT_FLAGS
            );
        }

        protected override void activate() {
            initialize_services();

            if (bar_window == null) {
                bar_window = new BarWindow(this, settings_store, monitor_manager, menu_builder, plugin_manager, log_service);
            }

            bar_window.present();
        }

        private void initialize_services() {
            if (settings_store != null) {
                return;
            }

            settings_store = new SettingsStore();
            variables_store = new VariablesStore();
            log_service = new LogService();
            monitor_manager = new MonitorManager(log_service);
            plugin_runner = new PluginRunner(log_service, variables_store, settings_store);
            xbar_parser = new XbarParser();
            plugin_manager = new PluginManager(settings_store, plugin_runner, xbar_parser, log_service);
            action_dispatcher = new ActionDispatcher(this, log_service);
            menu_builder = new MenuBuilder(action_dispatcher);

            log_service.info("staba skeleton initialized");
        }
    }
}
