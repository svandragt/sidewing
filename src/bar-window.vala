namespace Staba {
    public class BarWindow : Gtk.ApplicationWindow {
        private SettingsStore settings_store;
        private MonitorManager monitor_manager;
        private MenuBuilder menu_builder;
        private PluginManager plugin_manager;
        private LogService log_service;
        private Gtk.Box items_box;

        public BarWindow(
            Gtk.Application app,
            SettingsStore settings_store,
            MonitorManager monitor_manager,
            MenuBuilder menu_builder,
            PluginManager plugin_manager,
            LogService log_service
        ) {
            Object(application: app, title: "staba");

            this.settings_store = settings_store;
            this.monitor_manager = monitor_manager;
            this.menu_builder = menu_builder;
            this.plugin_manager = plugin_manager;
            this.log_service = log_service;

            decorated = false;
            resizable = false;
            default_height = settings_store.bar_height;
            default_width = 800;

            items_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            items_box.margin_start = 12;
            items_box.margin_end = 12;
            items_box.margin_top = 6;
            items_box.margin_bottom = 6;

            var frame = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            frame.add_css_class("toolbar");
            frame.append(items_box);

            set_child(frame);

            populate_placeholder_items();
            update_monitor_binding();
        }

        private void populate_placeholder_items() {
            append_plugin_chip("staba");
            append_plugin_chip("IP: --");
            append_plugin_chip("Mem: --");
            append_plugin_chip("Disk: --");
        }

        private void append_plugin_chip(string title) {
            var button = new Gtk.MenuButton();
            button.label = title;
            button.valign = Gtk.Align.CENTER;
            button.set_popover(menu_builder.build_placeholder_menu(title));
            items_box.append(button);
        }

        private void update_monitor_binding() {
            var monitor = monitor_manager.get_selected_monitor(settings_store.selected_monitor_id);
            if (monitor == null) {
                log_service.warning("No monitor available for bar placement");
                return;
            }

            default_width = monitor.width;
            log_service.info(@"Binding bar window to monitor $(monitor.display_name)");
        }
    }
}
