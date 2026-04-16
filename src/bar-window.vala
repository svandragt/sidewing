namespace Sidewing {
    public class BarWindow : Gtk.ApplicationWindow {
        private SettingsStore settings_store;
        private MonitorManager monitor_manager;
        private MenuBuilder menu_builder;
        private PluginManager plugin_manager;
        private LogService log_service;
        private X.Atom net_wm_window_type_atom;
        private X.Atom net_wm_window_type_dock_atom;
        private X.Atom net_wm_window_type_normal_atom;
        private X.Atom net_wm_strut_atom;
        private X.Atom net_wm_strut_partial_atom;
        private Gtk.Box bar_frame;
        private Gtk.Box items_box;
        private Gtk.MenuButton settings_button;
        private Gee.ArrayList<Gtk.MenuButton> plugin_buttons;
        private Gee.HashMap<string, Gtk.MenuButton> buttons_by_plugin_path;
        private int last_applied_bar_height = -1;

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

            bar_frame = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            bar_frame.add_css_class("sidewing-bar");
            bar_frame.append(items_box);
            bar_frame.append(settings_box);

            set_child(bar_frame);
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
            map.connect(() => {
                log_service.info("Bar window mapped; reapplying X11 placement and window role");
                queue_placement();
            });

            notify["is-active"].connect(() => {
                if (!is_active) {
                    log_service.info("Bar window deactivated; dismissing open menus");
                    close_all_menus();
                }
            });

            settings_store.stacking_preferences_changed.connect(() => {
                log_service.info("Stacking preference changed; reapplying X11 placement");
                queue_placement();
            });
        }

        public override void size_allocate(int width, int height, int baseline) {
            base.size_allocate(width, height, baseline);
            update_reserved_space_from_allocation(height);
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

            set_default_size(monitor.width, get_bar_pixel_height());
            settings_store.update_selected_monitor_id(monitor.id);
            log_service.info(@"Binding bar window to monitor $(monitor.display_name)");
        }

        private int get_bar_pixel_height() {
            var surface = get_surface();
            if (surface != null) {
                int surface_height = surface.get_height();
                if (surface_height > 0) {
                    return surface_height;
                }
            }

            int allocated_height = get_height();
            if (allocated_height > 0) {
                return allocated_height;
            }

            int frame_allocated_height = bar_frame.get_height();
            if (frame_allocated_height > 0) {
                return frame_allocated_height;
            }

            int minimum = settings_store.bar_height;
            int natural = settings_store.bar_height;

            bar_frame.measure(Gtk.Orientation.VERTICAL, -1, out minimum, out natural, null, null);
            return int.max(settings_store.bar_height, minimum);
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
            int bar_pixel_height = get_bar_pixel_height();
            cache_net_wm_atoms(x11_display);
            xdisplay.move_resize_window(
                xid,
                monitor.x,
                monitor.y,
                (uint) monitor.width,
                (uint) bar_pixel_height
            );
            apply_x11_window_role(xdisplay, xid, monitor, bar_pixel_height);
            xdisplay.raise_window(xid);
            xdisplay.flush();
        }

        private void cache_net_wm_atoms(Gdk.X11.Display x11_display) {
            if ((ulong) net_wm_window_type_atom != 0) {
                return;
            }

            net_wm_window_type_atom = x11_display.get_xatom_by_name("_NET_WM_WINDOW_TYPE");
            net_wm_window_type_dock_atom = x11_display.get_xatom_by_name("_NET_WM_WINDOW_TYPE_DOCK");
            net_wm_window_type_normal_atom = x11_display.get_xatom_by_name("_NET_WM_WINDOW_TYPE_NORMAL");
            net_wm_strut_atom = x11_display.get_xatom_by_name("_NET_WM_STRUT");
            net_wm_strut_partial_atom = x11_display.get_xatom_by_name("_NET_WM_STRUT_PARTIAL");
        }

        private void apply_x11_window_role(X.Display xdisplay, X.Window xid, MonitorInfo monitor, int bar_height) {
            if (settings_store.reserve_space_for_maximized_windows) {
                set_atom_property(xdisplay, xid, net_wm_window_type_atom, net_wm_window_type_dock_atom);
                set_strut_properties(xdisplay, xid, monitor, bar_height);
                last_applied_bar_height = bar_height;
            } else {
                set_atom_property(xdisplay, xid, net_wm_window_type_atom, net_wm_window_type_normal_atom);
                xdisplay.delete_property(xid, net_wm_strut_atom);
                xdisplay.delete_property(xid, net_wm_strut_partial_atom);
                last_applied_bar_height = -1;
            }
        }

        private void set_atom_property(
            X.Display xdisplay,
            X.Window xid,
            X.Atom property_atom,
            X.Atom value_atom
        ) {
            uint32[] values = { (uint32) value_atom };
            xdisplay.change_property(
                xid,
                property_atom,
                X.XA_ATOM,
                32,
                X.PropMode.Replace,
                encode_uint32(values),
                values.length
            );
        }

        private void set_strut_properties(X.Display xdisplay, X.Window xid, MonitorInfo monitor, int bar_height) {
            uint32 top = (uint32) (monitor.y + bar_height);
            uint32 start_x = (uint32) monitor.x;
            uint32 end_x = (uint32) (monitor.x + monitor.width - 1);

            uint32[] strut = { 0, 0, top, 0 };
            xdisplay.change_property(
                xid,
                net_wm_strut_atom,
                X.XA_CARDINAL,
                32,
                X.PropMode.Replace,
                encode_uint32(strut),
                strut.length
            );

            uint32[] strut_partial = {
                0, 0, top, 0,
                0, 0, 0, 0,
                start_x, end_x,
                0, 0
            };
            xdisplay.change_property(
                xid,
                net_wm_strut_partial_atom,
                X.XA_CARDINAL,
                32,
                X.PropMode.Replace,
                encode_uint32(strut_partial),
                strut_partial.length
            );
        }

        private uchar[] encode_uint32(uint32[] values) {
            int word_size = (int) sizeof(ulong);
            var bytes = new uchar[values.length * word_size];

            for (int i = 0; i < values.length; i++) {
                uint32 value = values[i];
                int offset = i * word_size;

                if (ByteOrder.HOST == ByteOrder.LITTLE_ENDIAN) {
                    bytes[offset] = (uchar) (value & 0xff);
                    bytes[offset + 1] = (uchar) ((value >> 8) & 0xff);
                    bytes[offset + 2] = (uchar) ((value >> 16) & 0xff);
                    bytes[offset + 3] = (uchar) ((value >> 24) & 0xff);
                } else {
                    bytes[offset + word_size - 1] = (uchar) (value & 0xff);
                    bytes[offset + word_size - 2] = (uchar) ((value >> 8) & 0xff);
                    bytes[offset + word_size - 3] = (uchar) ((value >> 16) & 0xff);
                    bytes[offset + word_size - 4] = (uchar) ((value >> 24) & 0xff);
                }
            }

            return bytes;
        }

        private void update_reserved_space_from_allocation(int allocated_height) {
            if (!settings_store.reserve_space_for_maximized_windows || allocated_height <= 0) {
                return;
            }

            if (allocated_height == last_applied_bar_height) {
                return;
            }

            var monitor = monitor_manager.get_selected_monitor(settings_store.selected_monitor_id);
            var display = Gdk.Display.get_default();
            var x11_display = display as Gdk.X11.Display;
            var surface = get_surface();
            var x11_surface = surface as Gdk.X11.Surface;

            if (monitor == null || x11_display == null || x11_surface == null) {
                return;
            }

            log_service.info(@"Updating reserved top space to exact allocated height $(allocated_height)px");
            unowned X.Display xdisplay = x11_display.get_xdisplay();
            X.Window xid = x11_surface.get_xid();
            cache_net_wm_atoms(x11_display);
            apply_x11_window_role(xdisplay, xid, monitor, allocated_height);
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
