namespace Sidewing {
    public class Application : Gtk.Application {
        private SettingsStore settings_store;
        private VariablesStore variables_store;
        private LogService log_service;
        private DesktopIntegration desktop_integration;
        private MonitorManager monitor_manager;
        private PluginRunner plugin_runner;
        private XbarParser xbar_parser;
        private PluginManager plugin_manager;
        private ActionDispatcher action_dispatcher;
        private MenuBuilder menu_builder;
        private BarWindow? bar_window;

        public Application() {
            Object(
                application_id: "com.vandragt.sidewing",
                flags: ApplicationFlags.DEFAULT_FLAGS
            );
        }

        protected override void activate() {
            initialize_services();
            log_service.info("Application activate start");

            if (bar_window == null) {
                log_service.info("Creating bar window");
                bar_window = new BarWindow(this, settings_store, monitor_manager, menu_builder, plugin_manager, log_service);
            }

            log_service.info("Presenting bar window");
            bar_window.present();
            log_service.info("Queueing X11 placement");
            bar_window.queue_placement();
            Idle.add(() => {
                log_service.info("Starting plugins after initial present");
                bar_window.start_plugins();
                return Source.REMOVE;
            });
            log_service.info("Application activate end");
        }

        private void initialize_services() {
            if (settings_store != null) {
                return;
            }

            settings_store = new SettingsStore();
            log_service = new LogService();
            variables_store = new VariablesStore(log_service);
            desktop_integration = new DesktopIntegration(log_service);
            settings_store.ensure_plugins_dir_seeded(log_service);
            monitor_manager = new MonitorManager(log_service);
            plugin_runner = new PluginRunner(log_service, variables_store, settings_store);
            xbar_parser = new XbarParser();
            plugin_manager = new PluginManager(
                settings_store,
                variables_store,
                plugin_runner,
                xbar_parser,
                log_service
            );
            action_dispatcher = new ActionDispatcher(this, log_service);
            menu_builder = new MenuBuilder(action_dispatcher, plugin_manager, settings_store, desktop_integration);
            load_css();

            log_service.info("Sidewing initialized");
        }

        private void load_css() {
            var provider = new Gtk.CssProvider();
            provider.load_from_string("""
                window.sidewing-window {
                    background: rgba(28, 30, 34, 0.94);
                    color: rgba(255, 255, 255, 0.94);
                }

                .sidewing-bar {
                    min-height: 28px;
                    padding: 0;
                    background: rgba(28, 30, 34, 0.94);
                    color: #d7dae0;
                }

                .sidewing-bar,
                .sidewing-bar label,
                .sidewing-bar button,
                .sidewing-bar button label,
                .sidewing-bar menubutton,
                .sidewing-bar menubutton label,
                .sidewing-bar image {
                    color: #d7dae0;
                }

                .sidewing-item {
                    min-height: 24px;
                    padding: 0 8px;
                    margin: 0 1px;
                    border-radius: 6px;
                    color: #d7dae0;
                    font-size: 10.5pt;
                    font-weight: 600;
                    background: transparent;
                }

                .sidewing-item label {
                    color: #d7dae0;
                }

                .sidewing-item-label {
                    color: #d7dae0;
                }

                .sidewing-item:hover {
                    background: rgba(255, 255, 255, 0.10);
                    color: #f2f4f8;
                }

                .sidewing-item:hover label {
                    color: #f2f4f8;
                }

                popover contents,
                .sidewing-menu {
                    background: rgba(33, 35, 40, 0.98);
                    color: rgba(255, 255, 255, 0.94);
                    border-radius: 10px;
                }

                .sidewing-menu-item {
                    min-height: 26px;
                    padding: 4px 8px;
                    border-radius: 6px;
                    color: rgba(255, 255, 255, 0.94);
                }

                .sidewing-menu-item:hover {
                    background: rgba(255, 255, 255, 0.10);
                }

                .warning {
                    color: #ffb36b;
                }
            """);

            var display = Gdk.Display.get_default();
            if (display != null) {
                Gtk.StyleContext.add_provider_for_display(
                    display,
                    provider,
                    Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
                );
            }
        }
    }
}
