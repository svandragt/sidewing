namespace Sidewing {
    public class VariablesEditor : Object {
        private VariablesStore variables_store;
        private PluginManager plugin_manager;
        private LogService log_service;

        public VariablesEditor(
            VariablesStore variables_store,
            PluginManager plugin_manager,
            LogService log_service
        ) {
            this.variables_store = variables_store;
            this.plugin_manager = plugin_manager;
            this.log_service = log_service;
        }

        public void present(Gtk.Application application, PluginRecord record) {
            var plugin = record.definition;
            if (plugin.variable_definitions.size == 0) {
                return;
            }

            var window = new Gtk.Window();
            window.set_application(application);
            window.set_title(@"Variables — $(plugin.display_name)");
            window.set_default_size(520, -1);
            window.set_modal(true);
            window.set_resizable(true);

            var header = new Gtk.HeaderBar();
            header.set_show_title_buttons(false);
            window.set_titlebar(header);

            var cancel_button = new Gtk.Button.with_label("Cancel");
            cancel_button.clicked.connect(() => window.close());
            header.pack_start(cancel_button);

            var save_button = new Gtk.Button.with_label("Save");
            save_button.add_css_class("suggested-action");
            header.pack_end(save_button);

            var outer = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            outer.margin_start = 16;
            outer.margin_end = 16;
            outer.margin_top = 16;
            outer.margin_bottom = 16;

            var grid = new Gtk.Grid();
            grid.column_spacing = 12;
            grid.row_spacing = 10;
            grid.hexpand = true;

            var collectors = new Gee.ArrayList<ValueCollector>();
            int row = 0;
            foreach (var definition in plugin.variable_definitions) {
                var name_label = new Gtk.Label(definition.name);
                name_label.halign = Gtk.Align.START;
                name_label.valign = Gtk.Align.START;
                name_label.add_css_class("heading");
                grid.attach(name_label, 0, row, 1, 1);

                string current = variables_store.read_value(plugin, definition);
                Gtk.Widget input;
                ValueCollector collector;
                build_input(definition, current, out input, out collector);
                input.hexpand = true;
                grid.attach(input, 1, row, 1, 1);
                collectors.add(collector);
                row++;

                if (definition.description != "") {
                    var desc = new Gtk.Label(definition.description);
                    desc.halign = Gtk.Align.START;
                    desc.xalign = 0.0f;
                    desc.wrap = true;
                    desc.add_css_class("dim-label");
                    desc.add_css_class("caption");
                    grid.attach(desc, 1, row, 1, 1);
                    row++;
                }
            }

            var scrolled = new Gtk.ScrolledWindow();
            scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            scrolled.set_child(grid);
            scrolled.vexpand = true;
            scrolled.set_min_content_height(120);
            scrolled.set_propagate_natural_height(true);
            outer.append(scrolled);

            window.set_child(outer);

            save_button.clicked.connect(() => {
                var values = new Gee.HashMap<string, string>();
                foreach (var collector in collectors) {
                    values.set(collector.name, collector.collect());
                }
                variables_store.write_values(plugin, values);
                log_service.info(@"Saved variables for $(plugin.filename)");
                plugin_manager.refresh_record(record);
                window.close();
            });

            window.present();
        }

        private void build_input(
            PluginVariableDefinition definition,
            string current,
            out Gtk.Widget input,
            out ValueCollector collector
        ) {
            switch (definition.variable_type) {
            case PluginVariableType.BOOLEAN:
                var toggle = new Gtk.Switch();
                toggle.halign = Gtk.Align.START;
                toggle.set_active(current.down() == "true");
                input = toggle;
                collector = new ValueCollector(definition.name, () => {
                    return toggle.get_active() ? "true" : "false";
                });
                break;
            case PluginVariableType.NUMBER:
                var entry = new Gtk.Entry();
                entry.set_text(current);
                entry.set_input_purpose(Gtk.InputPurpose.NUMBER);
                input = entry;
                collector = new ValueCollector(definition.name, () => entry.get_text());
                break;
            case PluginVariableType.SELECT:
                var dropdown_strings = new Gtk.StringList(null);
                int selected = 0;
                int idx = 0;
                foreach (var option in definition.options) {
                    dropdown_strings.append(option);
                    if (option == current) {
                        selected = idx;
                    }
                    idx++;
                }
                var dropdown = new Gtk.DropDown(dropdown_strings, null);
                dropdown.set_selected(selected);
                input = dropdown;
                collector = new ValueCollector(definition.name, () => {
                    uint pos = dropdown.get_selected();
                    if (pos < definition.options.size) {
                        return definition.options.get((int) pos);
                    }
                    return definition.default_value;
                });
                break;
            case PluginVariableType.STRING:
            default:
                var entry = new Gtk.Entry();
                entry.set_text(current);
                entry.hexpand = true;
                if (looks_like_secret(definition.name)) {
                    entry.set_visibility(false);
                    entry.set_input_purpose(Gtk.InputPurpose.PASSWORD);
                }
                input = entry;
                collector = new ValueCollector(definition.name, () => entry.get_text());
                break;
            }
        }

        private bool looks_like_secret(string name) {
            string upper = name.up();
            return upper.contains("TOKEN")
                || upper.contains("SECRET")
                || upper.contains("PASSWORD")
                || upper.contains("API_KEY")
                || upper.contains("APIKEY");
        }
    }

    public delegate string ValueGetter();

    public class ValueCollector : Object {
        public string name { get; construct set; }
        private ValueGetter getter;

        public ValueCollector(string name, owned ValueGetter getter) {
            Object(name: name);
            this.getter = (owned) getter;
        }

        public string collect() {
            return getter();
        }
    }
}
