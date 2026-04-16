namespace Sidewing {
    public class BarWindow : Gtk.ApplicationWindow {
        private SettingsStore settings_store;
        private MonitorManager monitor_manager;
        private MenuBuilder menu_builder;
        private PluginManager plugin_manager;
        private LogService log_service;
        private Gtk.Box items_box;
        private Gtk.MenuButton settings_button;
        private Gee.ArrayList<Gtk.MenuButton> plugin_buttons;
        private Gee.HashMap<string, Gtk.MenuButton> buttons_by_plugin_path;

        public BarWindow(
            Gtk.Application app,
            SettingsStore settings_store,
            MonitorManager monitor_manager,
            MenuBuilder menu_builder,
            PluginManager plugin_manager,
            LogService log_service
        ) {
            Object(application: app, title: "Sidewing");

            this.settings_store = settings_store;
            this.monitor_manager = monitor_manager;
            this.menu_builder = menu_builder;
            this.plugin_manager = plugin_manager;
            this.log_service = log_service;

            decorated = false;
            resizable = false;
            default_height = settings_store.bar_height;
            default_width = 800;
            add_css_class("sidewing-window");

            items_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
            items_box.margin_start = 12;
            items_box.margin_top = 6;
            items_box.margin_bottom = 6;
            items_box.hexpand = true;

            var settings_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            settings_box.margin_end = 12;
            settings_box.margin_top = 6;
            settings_box.margin_bottom = 6;

            settings_button = new Gtk.MenuButton();
            settings_button.valign = Gtk.Align.CENTER;
            settings_button.add_css_class("flat");
            settings_button.add_css_class("sidewing-item");
            settings_button.set_has_frame(false);
            settings_button.set_always_show_arrow(false);
            settings_button.set_direction(Gtk.ArrowType.NONE);
            settings_button.tooltip_text = "Settings";
            settings_button.set_popover(menu_builder.build_app_menu());

            var settings_icon = new Gtk.Image.from_icon_name("emblem-system-symbolic");
            settings_button.set_child(settings_icon);
            settings_box.append(settings_button);

            plugin_buttons = new Gee.ArrayList<Gtk.MenuButton>();
            buttons_by_plugin_path = new Gee.HashMap<string, Gtk.MenuButton>();

            var frame = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            frame.add_css_class("sidewing-bar");
            frame.append(items_box);
            frame.append(settings_box);

            set_child(frame);
            log_service.info("Bar window initialized widgets");
            update_monitor_binding();
            bind_window_state();
            bind_plugin_manager();
        }

        public void queue_placement() {
            Idle.add(() => {
                log_service.info("Running queued bar placement");
                place_on_selected_monitor();
                return Source.REMOVE;
            });
        }

        public void start_plugins() {
            log_service.info("Starting plugin manager");
            plugin_manager.start();
        }

        private void bind_plugin_manager() {
            plugin_manager.plugins_changed.connect(() => {
                log_service.info("plugins_changed received; rebuilding bar items");
                rebuild_items();
            });

            plugin_manager.plugin_updated.connect((record) => {
                log_service.info(@"plugin_updated received for $(record.definition.filename)");
                update_plugin_chip(record);
            });
        }

        private void bind_window_state() {
            notify["is-active"].connect(() => {
                if (!is_active) {
                    log_service.info("Bar window deactivated; dismissing open menus");
                    close_all_menus();
                }
            });
        }

        private void rebuild_items() {
            log_service.info("Rebuilding all bar items");
            plugin_buttons.clear();
            buttons_by_plugin_path.clear();

            Gtk.Widget? child = items_box.get_first_child();
            while (child != null) {
                Gtk.Widget? next = child.get_next_sibling();
                items_box.remove(child);
                child = next;
            }

            var records = plugin_manager.get_records();
            if (records.size == 0) {
                log_service.info("No plugins discovered for bar");
                append_message_chip("No executable plugins");
                return;
            }

            log_service.info(@"Rendering $(records.size) plugin buttons");
            foreach (var record in records) {
                append_plugin_chip(record);
            }
        }

        private void append_plugin_chip(PluginRecord record) {
            var button = new Gtk.MenuButton();
            string label = record.state.visible_title;
            if (label == "Sidewing" || label == "") {
                label = record.definition.display_name;
            }

            button.valign = Gtk.Align.CENTER;
            button.add_css_class("flat");
            button.add_css_class("sidewing-item");
            button.set_has_frame(false);
            button.set_always_show_arrow(false);
            button.set_direction(Gtk.ArrowType.NONE);
            button.set_popover(menu_builder.build_plugin_menu(record));

            var title = new Gtk.Label(label);
            title.add_css_class("sidewing-item-label");
            title.ellipsize = Pango.EllipsizeMode.END;
            button.set_child(title);

            var click = new Gtk.GestureClick();
            click.set_button(Gdk.BUTTON_PRIMARY);
            click.pressed.connect((n_press, x, y) => {
                popdown_other_buttons(button);
            });
            button.add_controller(click);

            plugin_buttons.add(button);
            buttons_by_plugin_path.set(record.definition.path, button);
            items_box.append(button);
        }

        private void append_message_chip(string title) {
            var label = new Gtk.Label(title);
            label.halign = Gtk.Align.START;
            label.add_css_class("sidewing-item");
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

        private void popdown_other_buttons(Gtk.MenuButton active_button) {
            foreach (var button in plugin_buttons) {
                if (button != active_button) {
                    button.popdown();
                }
            }
        }

        private void close_all_menus() {
            foreach (var button in plugin_buttons) {
                button.popdown();
            }
        }

        private void update_plugin_chip(PluginRecord record) {
            log_service.info(@"Updating bar item in place for $(record.definition.filename)");
            var button = buttons_by_plugin_path.get(record.definition.path);
            if (button == null) {
                log_service.warning(@"No existing button found for $(record.definition.filename); rebuilding");
                rebuild_items();
                return;
            }

            string label = record.state.visible_title;
            if (label == "Sidewing" || label == "") {
                label = record.definition.display_name;
            }

            var child = button.get_child();
            var title = child as Gtk.Label;
            if (title != null) {
                title.set_label(label);
            }

            var popover = button.get_popover();
            if (popover != null) {
                menu_builder.populate_plugin_menu(popover, record);
            } else {
                button.set_popover(menu_builder.build_plugin_menu(record));
            }
        }
    }
}
