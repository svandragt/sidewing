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
        private X.Atom net_active_window_atom;
        private X.Atom net_client_list_stacking_atom;
        private X.Atom net_wm_state_atom;
        private X.Atom net_wm_state_maximized_vert_atom;
        private X.Atom net_wm_state_maximized_horz_atom;
        private Gtk.Box bar_frame;
        private Gtk.Box items_box;
        private Gtk.MenuButton settings_button;
        private Gee.ArrayList<Gtk.MenuButton> plugin_buttons;
        private Gee.HashMap<string, Gtk.MenuButton> buttons_by_plugin_path;
        private int last_applied_bar_height = -1;
        private bool has_maximized_window_on_monitor = false;
        private bool has_x11_focus = false;
        private uint maximized_window_poll_id = 0;

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

            items_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 4);
            items_box.margin_start = 8;
            items_box.margin_top = 0;
            items_box.margin_bottom = 2;
            items_box.hexpand = true;

            var settings_box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
            settings_box.margin_end = 8;
            settings_box.margin_top = 0;
            settings_box.margin_bottom = 2;

            settings_button = new Gtk.MenuButton();
            settings_button.valign = Gtk.Align.FILL;
            settings_button.add_css_class("flat");
            settings_button.add_css_class("sidewing-item");
            settings_button.add_css_class("composited-indicator");
            settings_button.set_has_frame(false);
            settings_button.set_always_show_arrow(false);
            settings_button.set_direction(Gtk.ArrowType.NONE);
            settings_button.tooltip_text = "Settings";
            settings_button.set_popover(menu_builder.build_app_menu());

            var settings_click = new Gtk.GestureClick();
            settings_click.set_button(Gdk.BUTTON_PRIMARY);
            settings_click.pressed.connect((n_press, x, y) => {
                popdown_other_buttons(settings_button);
            });
            settings_button.add_controller(settings_click);

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
            sync_bar_background_mode();
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
                start_maximized_window_tracking();
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

            close_request.connect(() => {
                stop_maximized_window_tracking();
                return false;
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

            button.valign = Gtk.Align.FILL;
            button.add_css_class("flat");
            button.add_css_class("sidewing-item");
            button.add_css_class("composited-indicator");
            button.set_has_frame(false);
            button.set_always_show_arrow(false);
            button.set_direction(Gtk.ArrowType.NONE);
            button.set_popover(menu_builder.build_plugin_menu(record));

            var title = new Gtk.Label(label);
            title.add_css_class("sidewing-item-label");
            title.add_css_class("composited-indicator-label");
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
            label.add_css_class("composited-indicator");
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
            net_active_window_atom = x11_display.get_xatom_by_name("_NET_ACTIVE_WINDOW");
            net_client_list_stacking_atom = x11_display.get_xatom_by_name("_NET_CLIENT_LIST_STACKING");
            net_wm_state_atom = x11_display.get_xatom_by_name("_NET_WM_STATE");
            net_wm_state_maximized_vert_atom = x11_display.get_xatom_by_name("_NET_WM_STATE_MAXIMIZED_VERT");
            net_wm_state_maximized_horz_atom = x11_display.get_xatom_by_name("_NET_WM_STATE_MAXIMIZED_HORZ");
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

        private void start_maximized_window_tracking() {
            if (maximized_window_poll_id != 0) {
                return;
            }

            update_tracked_window_state();
            maximized_window_poll_id = Timeout.add(250, () => {
                update_tracked_window_state();
                return Source.CONTINUE;
            });
        }

        private void stop_maximized_window_tracking() {
            if (maximized_window_poll_id == 0) {
                return;
            }

            Source.remove(maximized_window_poll_id);
            maximized_window_poll_id = 0;
        }

        private void update_bar_background_mode() {
            var monitor = monitor_manager.get_selected_monitor(settings_store.selected_monitor_id);
            var display = Gdk.Display.get_default();
            var x11_display = display as Gdk.X11.Display;

            if (monitor == null || x11_display == null) {
                update_x11_focus_state(false);
                set_has_maximized_window_on_monitor(false);
                return;
            }

            unowned X.Display xdisplay = x11_display.get_xdisplay();
            cache_net_wm_atoms(x11_display);
            bool owned_active = any_owned_window_is_active(xdisplay);
            update_x11_focus_state(owned_active);
            dismiss_menus_if_focus_elsewhere(owned_active);
            set_has_maximized_window_on_monitor(
                active_window_is_maximized_on_monitor(xdisplay, monitor)
            );
        }

        private X.Window? active_window_at_popover_open = null;
        private bool popovers_were_open = false;

        private void dismiss_menus_if_focus_elsewhere(bool owned_active) {
            var open_popovers = collect_open_popover_xids();
            if (open_popovers.size == 0) {
                popovers_were_open = false;
                active_window_at_popover_open = null;
                return;
            }

            var display = Gdk.Display.get_default() as Gdk.X11.Display;
            if (display == null) {
                return;
            }
            unowned X.Display xdisplay = display.get_xdisplay();
            X.Window? current_active = read_window_property(
                xdisplay,
                xdisplay.default_root_window(),
                net_active_window_atom
            );

            if (!popovers_were_open) {
                popovers_were_open = true;
                active_window_at_popover_open = current_active;
                return;
            }

            if (owned_active) {
                return;
            }

            if (current_active == active_window_at_popover_open) {
                return;
            }

            log_service.info("Active window changed while popover was open; dismissing open menus");
            close_all_menus();
        }

        private void update_tracked_window_state() {
            update_bar_background_mode();
        }

        private bool active_window_is_maximized_on_monitor(X.Display xdisplay, MonitorInfo monitor) {
            X.Window? own_window = get_own_x11_window();
            X.Window? active_window = read_window_property(
                xdisplay,
                xdisplay.default_root_window(),
                net_active_window_atom
            );

            if (active_window != null && active_window != 0 && active_window != own_window) {
                return window_is_maximized_on_monitor(xdisplay, active_window, monitor);
            }

            X.Window? stacked_window = find_topmost_maximized_window_on_monitor(
                xdisplay,
                monitor,
                own_window
            );
            return stacked_window != null;
        }

        private bool any_owned_window_is_active(X.Display xdisplay) {
            X.Window? active_window = read_window_property(
                xdisplay,
                xdisplay.default_root_window(),
                net_active_window_atom
            );

            if (active_window == null || active_window == 0) {
                return false;
            }

            X.Window? own = get_own_x11_window();
            if (own != null && active_window == own) {
                return true;
            }

            foreach (var xid in collect_open_popover_xids()) {
                if (active_window == xid) {
                    return true;
                }
            }

            return false;
        }

        private Gee.ArrayList<X.Window?> collect_open_popover_xids() {
            var result = new Gee.ArrayList<X.Window?>();
            add_popover_xid(result, settings_button);
            foreach (var button in plugin_buttons) {
                add_popover_xid(result, button);
            }
            return result;
        }

        private void add_popover_xid(Gee.ArrayList<X.Window?> result, Gtk.MenuButton button) {
            var popover = button.get_popover();
            if (popover == null || !popover.get_visible()) {
                return;
            }

            var surface = popover.get_native() != null ? popover.get_native().get_surface() : null;
            var x11_surface = surface as Gdk.X11.Surface;
            if (x11_surface == null) {
                return;
            }

            result.add(x11_surface.get_xid());
        }

private X.Window? find_topmost_maximized_window_on_monitor(
            X.Display xdisplay,
            MonitorInfo monitor,
            X.Window? ignored_window
        ) {
            var windows = read_window_list_property(
                xdisplay,
                xdisplay.default_root_window(),
                net_client_list_stacking_atom
            );

            for (int i = windows.length - 1; i >= 0; i--) {
                X.Window window = windows[i];
                if (window == 0 || window == ignored_window) {
                    continue;
                }

                if (window_is_maximized_on_monitor(xdisplay, window, monitor)) {
                    return window;
                }
            }

            return null;
        }

        private bool window_is_maximized_on_monitor(X.Display xdisplay, X.Window window, MonitorInfo monitor) {
            if (!window_has_atom_state(xdisplay, window, net_wm_state_maximized_vert_atom)) {
                return false;
            }

            if (!window_has_atom_state(xdisplay, window, net_wm_state_maximized_horz_atom)) {
                return false;
            }

            return window_is_on_monitor(xdisplay, window, monitor);
        }

        private X.Window? read_window_property(X.Display xdisplay, X.Window window, X.Atom property_atom) {
            X.Atom actual_type;
            int actual_format;
            ulong nitems;
            ulong bytes_after;
            void* data = null;

            int result = xdisplay.get_window_property(
                window,
                property_atom,
                0,
                1,
                false,
                (X.Atom) X.ANY_PROPERTY_TYPE,
                out actual_type,
                out actual_format,
                out nitems,
                out bytes_after,
                out data
            );

            if (result != X.Success || data == null || actual_format != 32 || nitems == 0) {
                if (data != null) {
                    X.free(data);
                }
                return null;
            }

            X.Window active_window = ((ulong*) data)[0];
            X.free(data);
            return active_window;
        }

        private X.Window[] read_window_list_property(X.Display xdisplay, X.Window window, X.Atom property_atom) {
            X.Atom actual_type;
            int actual_format;
            ulong nitems;
            ulong bytes_after;
            void* data = null;

            int result = xdisplay.get_window_property(
                window,
                property_atom,
                0,
                4096,
                false,
                (X.Atom) X.ANY_PROPERTY_TYPE,
                out actual_type,
                out actual_format,
                out nitems,
                out bytes_after,
                out data
            );

            if (result != X.Success || data == null || actual_format != 32 || nitems == 0) {
                if (data != null) {
                    X.free(data);
                }
                return {};
            }

            var windows = new X.Window[(int) nitems];
            ulong* items = (ulong*) data;
            for (ulong i = 0; i < nitems; i++) {
                windows[(int) i] = (X.Window) items[i];
            }

            X.free(data);
            return windows;
        }

        private bool window_has_atom_state(X.Display xdisplay, X.Window window, X.Atom expected_atom) {
            X.Atom actual_type;
            int actual_format;
            ulong nitems;
            ulong bytes_after;
            void* data = null;

            int result = xdisplay.get_window_property(
                window,
                net_wm_state_atom,
                0,
                32,
                false,
                X.XA_ATOM,
                out actual_type,
                out actual_format,
                out nitems,
                out bytes_after,
                out data
            );

            if (result != X.Success || data == null || actual_format != 32 || nitems == 0) {
                if (data != null) {
                    X.free(data);
                }
                return false;
            }

            bool found = false;
            ulong* atoms = (ulong*) data;
            for (ulong i = 0; i < nitems; i++) {
                if ((X.Atom) atoms[i] == expected_atom) {
                    found = true;
                    break;
                }
            }

            X.free(data);
            return found;
        }

        private bool window_is_on_monitor(X.Display xdisplay, X.Window window, MonitorInfo monitor) {
            int root_x;
            int root_y;
            X.Window child_return;

            bool translated = xdisplay.translate_coordinates(
                window,
                xdisplay.default_root_window(),
                0,
                0,
                out root_x,
                out root_y,
                out child_return
            );
            if (!translated) {
                return false;
            }

            X.Window root_return;
            int unused_x;
            int unused_y;
            uint width;
            uint height;
            uint border_width;
            uint depth;
            xdisplay.get_geometry(
                window,
                out root_return,
                out unused_x,
                out unused_y,
                out width,
                out height,
                out border_width,
                out depth
            );

            int horizontal_overlap = int.min(root_x + (int) width, monitor.x + monitor.width) - int.max(root_x, monitor.x);
            int vertical_overlap = int.min(root_y + (int) height, monitor.y + monitor.height) - int.max(root_y, monitor.y);

            return horizontal_overlap > 0 && vertical_overlap > 0;
        }

        private void set_has_maximized_window_on_monitor(bool value) {
            if (has_maximized_window_on_monitor == value) {
                return;
            }

            has_maximized_window_on_monitor = value;
            sync_bar_background_mode();
            log_service.info(
                value
                    ? "Active maximized window detected on selected monitor; using opaque bar background"
                    : "No active maximized window on selected monitor; using translucent bar background"
            );
        }

        private void sync_bar_background_mode() {
            if (has_maximized_window_on_monitor) {
                bar_frame.add_css_class("sidewing-bar-opaque");
            } else {
                bar_frame.remove_css_class("sidewing-bar-opaque");
            }
        }

        private void update_x11_focus_state(bool focused) {
            if (has_x11_focus == focused) {
                return;
            }

            has_x11_focus = focused;
        }

        private X.Window? get_own_x11_window() {
            var surface = get_surface();
            var x11_surface = surface as Gdk.X11.Surface;
            if (x11_surface == null) {
                return null;
            }

            return x11_surface.get_xid();
        }

        private void popdown_other_buttons(Gtk.MenuButton active_button) {
            if (settings_button != active_button) {
                settings_button.popdown();
            }

            foreach (var button in plugin_buttons) {
                if (button != active_button) {
                    button.popdown();
                }
            }
        }

        private void close_all_menus() {
            settings_button.popdown();

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
