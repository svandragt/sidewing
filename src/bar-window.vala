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
            add_css_class("staba-window");

            items_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            items_box.margin_start = 12;
            items_box.margin_end = 12;
            items_box.margin_top = 6;
            items_box.margin_bottom = 6;

            var frame = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            frame.add_css_class("staba-bar");
            frame.append(items_box);

            set_child(frame);
            update_monitor_binding();
            bind_plugin_manager();
            plugin_manager.start();
        }

        public void queue_placement() {
            Idle.add(() => {
                place_on_selected_monitor();
                return Source.REMOVE;
            });
        }

        private void bind_plugin_manager() {
            plugin_manager.plugins_changed.connect(() => {
                rebuild_items();
            });

            plugin_manager.plugin_updated.connect((record) => {
                rebuild_items();
            });
        }

        private void rebuild_items() {
            Gtk.Widget? child = items_box.get_first_child();
            while (child != null) {
                Gtk.Widget? next = child.get_next_sibling();
                items_box.remove(child);
                child = next;
            }

            var records = plugin_manager.get_records();
            if (records.size == 0) {
                append_message_chip("No executable plugins");
                return;
            }

            foreach (var record in records) {
                append_plugin_chip(record);
            }
        }

        private void append_plugin_chip(PluginRecord record) {
            var button = new Gtk.MenuButton();
            string label = record.state.visible_title;
            if (label == "staba" || label == "") {
                label = record.definition.display_name;
            }

            button.label = label;
            button.valign = Gtk.Align.CENTER;
            button.add_css_class("flat");
            button.add_css_class("staba-item");
            button.set_has_frame(false);
            button.set_popover(menu_builder.build_plugin_menu(record));
            items_box.append(button);
        }

        private void append_message_chip(string title) {
            var label = new Gtk.Label(title);
            label.halign = Gtk.Align.START;
            label.add_css_class("staba-item");
            items_box.append(label);
        }

        private void update_monitor_binding() {
            var monitor = monitor_manager.get_selected_monitor(settings_store.selected_monitor_id);
            if (monitor == null) {
                log_service.warning("No monitor available for bar placement");
                return;
            }

            set_default_size(monitor.width, settings_store.bar_height);
            settings_store.update_selected_monitor_id(monitor.id);
            log_service.info(@"Binding bar window to monitor $(monitor.display_name)");
        }

        private void place_on_selected_monitor() {
            var monitor = monitor_manager.get_selected_monitor(settings_store.selected_monitor_id);
            if (monitor == null) {
                return;
            }

            var display = Gdk.Display.get_default();
            var x11_display = display as Gdk.X11.Display;
            var surface = get_surface();
            var x11_surface = surface as Gdk.X11.Surface;

            if (x11_display == null || x11_surface == null) {
                log_service.warning("Precise monitor placement is only implemented for X11 right now");
                return;
            }

            x11_surface.set_skip_taskbar_hint(true);
            x11_surface.set_skip_pager_hint(true);
            x11_surface.move_to_current_desktop();
            x11_surface.set_frame_sync_enabled(false);

            unowned X.Display xdisplay = x11_display.get_xdisplay();
            X.Window xid = x11_surface.get_xid();
            xdisplay.move_resize_window(
                xid,
                monitor.x,
                monitor.y,
                (uint) monitor.width,
                (uint) settings_store.bar_height
            );
            xdisplay.raise_window(xid);
            xdisplay.flush();
        }
    }
}
