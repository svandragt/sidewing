namespace Sidewing {
    public class MenuBuilder : Object {
        private ActionDispatcher action_dispatcher;
        private PluginManager plugin_manager;

        public MenuBuilder(ActionDispatcher action_dispatcher, PluginManager plugin_manager) {
            this.action_dispatcher = action_dispatcher;
            this.plugin_manager = plugin_manager;
        }

        public Gtk.Widget build_plugin_menu(PluginRecord record) {
            var popover = new Gtk.Popover();
            popover.set_has_arrow(false);
            popover.set_autohide(false);
            popover.set_cascade_popdown(false);
            popover.set_position(Gtk.PositionType.BOTTOM);
            popover.set_offset(0, 6);
            populate_plugin_menu(popover, record);
            return popover;
        }

        public void populate_plugin_menu(Gtk.Popover popover, PluginRecord record) {
            var existing_child = popover.get_child();
            if (existing_child != null) {
                popover.set_child(null);
            }

            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
            box.margin_start = 12;
            box.margin_end = 12;
            box.margin_top = 12;
            box.margin_bottom = 12;
            box.add_css_class("sidewing-menu");

            var heading = new Gtk.Label(record.definition.display_name);
            heading.halign = Gtk.Align.START;
            heading.add_css_class("heading");

            box.append(heading);

            if (record.state.menu_items.size == 0) {
                box.append(build_info_label("No menu items"));
            } else {
                foreach (var item in record.state.menu_items) {
                    box.append(build_item_widget(record, item));
                }
            }

            if (record.state.warnings.size > 0) {
                box.append(new Gtk.Separator(Gtk.Orientation.HORIZONTAL));
                foreach (var warning_text in record.state.warnings) {
                    var warning = build_info_label(warning_text);
                    warning.add_css_class("warning");
                    box.append(warning);
                }
            }

            popover.set_child(box);
        }

        private Gtk.Widget build_item_widget(PluginRecord record, ParsedItem item) {
            if (item.kind == ParsedItemKind.SEPARATOR) {
                return new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
            }

            if (item.disabled) {
                var disabled_label = build_info_label(item.title);
                disabled_label.set_sensitive(false);
                return disabled_label;
            }

            var button = new Gtk.Button.with_label(item.title);
            button.halign = Gtk.Align.FILL;
            button.hexpand = true;
            button.add_css_class("flat");
            button.add_css_class("sidewing-menu-item");
            button.set_can_focus(false);

            if (item.depth > 0) {
                button.margin_start = (int) item.depth * 14;
            }

            button.clicked.connect(() => {
                if (item.refresh) {
                    plugin_manager.refresh_record(record);
                } else if (item.href != null) {
                    action_dispatcher.open_uri(item.href);
                }
            });

            return button;
        }

        private Gtk.Label build_info_label(string text) {
            var label = new Gtk.Label(text);
            label.halign = Gtk.Align.START;
            label.wrap = true;
            label.xalign = 0.0f;
            return label;
        }
    }
}
