namespace Sidewing {
    public class VariablesStore : Object {
        private LogService log_service;

        public VariablesStore(LogService log_service) {
            this.log_service = log_service;
        }

        public Gee.ArrayList<PluginVariableDefinition> load_variable_definitions(string plugin_path) {
            var definitions = new Gee.ArrayList<PluginVariableDefinition>();
            string contents;

            try {
                FileUtils.get_contents(plugin_path, out contents);
            } catch (Error err) {
                log_service.warning(@"Failed to read plugin metadata for $(plugin_path): $(err.message)");
                return definitions;
            }

            try {
                var regex = new Regex("""(?s)<xbar\.var>(.*?)</xbar\.var>""");
                MatchInfo info;
                regex.match(contents, 0, out info);

                while (info.matches()) {
                    var definition = parse_variable_block(info.fetch(1));
                    if (definition != null) {
                        definitions.add(definition);
                    }

                    info.next();
                }
            } catch (Error err) {
                log_service.warning(@"Failed to parse variable metadata for $(plugin_path): $(err.message)");
            }

            return definitions;
        }

        public void sync_sidecar(PluginDefinition plugin) {
            if (plugin.variable_definitions.size == 0) {
                return;
            }

            var sidecar = load_sidecar_object(plugin);
            bool changed = false;

            foreach (var definition in plugin.variable_definitions) {
                if (sidecar.has_member(definition.name)) {
                    continue;
                }

                set_member_value(sidecar, definition, definition.default_value);
                changed = true;
            }

            if (changed || !FileUtils.test(get_sidecar_path(plugin), FileTest.EXISTS)) {
                save_sidecar_object(plugin, sidecar);
            }
        }

        public void apply_to_launcher(SubprocessLauncher launcher, PluginDefinition plugin) {
            if (plugin.variable_definitions.size == 0) {
                return;
            }

            sync_sidecar(plugin);
            var sidecar = load_sidecar_object(plugin);

            foreach (var definition in plugin.variable_definitions) {
                string value = get_environment_value(sidecar, definition);
                launcher.setenv(definition.name, value, true);
            }
        }

        private PluginVariableDefinition? parse_variable_block(string block) {
            string normalized = normalize_block(block);
            try {
                var regex = new Regex(
                    """^(string|number|boolean|select)\(([A-Za-z_][A-Za-z0-9_]*)=(.*?)\)\s*:\s*(.*)$"""
                );
                MatchInfo info;
                if (!regex.match(normalized, 0, out info)) {
                    log_service.warning(@"Ignoring malformed xbar.var block: $normalized");
                    return null;
                }

                PluginVariableType variable_type = parse_variable_type(info.fetch(1));
                string name = info.fetch(2);
                string default_value = unquote(info.fetch(3).strip());
                string description = info.fetch(4).strip();
                var options = new Gee.ArrayList<string>();

                if (variable_type == PluginVariableType.SELECT) {
                    int options_start = description.last_index_of("[");
                    int options_end = description.last_index_of("]");
                    if (options_start >= 0 && options_end > options_start) {
                        string options_text = description.substring(
                            options_start + 1,
                            options_end - options_start - 1
                        );
                        description = description.substring(0, options_start).strip();
                        foreach (var option in options_text.split(",")) {
                            string cleaned = unquote(option.strip());
                            if (cleaned != "") {
                                options.add(cleaned);
                            }
                        }
                    }
                }

                return new PluginVariableDefinition(
                    variable_type,
                    name,
                    default_value,
                    description,
                    options
                );
            } catch (Error err) {
                log_service.warning(@"Ignoring malformed xbar.var block: $(err.message)");
                return null;
            }
        }

        private string normalize_block(string block) {
            var builder = new StringBuilder();
            foreach (var line in block.split("\n")) {
                string stripped = line.strip();
                if (stripped == "") {
                    continue;
                }

                string cleaned = strip_comment_prefix(stripped);
                if (builder.len > 0) {
                    builder.append(" ");
                }

                builder.append(cleaned);
            }

            return builder.str;
        }

        private string strip_comment_prefix(string line) {
            if (line.has_prefix("#")) {
                return line.substring(1).strip();
            }

            if (line.has_prefix("//")) {
                return line.substring(2).strip();
            }

            if (line.has_prefix("*")) {
                return line.substring(1).strip();
            }

            if (line.has_prefix(";")) {
                return line.substring(1).strip();
            }

            return line;
        }

        private PluginVariableType parse_variable_type(string type_name) {
            switch (type_name) {
            case "string":
                return PluginVariableType.STRING;
            case "number":
                return PluginVariableType.NUMBER;
            case "boolean":
                return PluginVariableType.BOOLEAN;
            case "select":
                return PluginVariableType.SELECT;
            default:
                return PluginVariableType.STRING;
            }
        }

        private string get_sidecar_path(PluginDefinition plugin) {
            return plugin.path + ".vars.json";
        }

        private Json.Object load_sidecar_object(PluginDefinition plugin) {
            string path = get_sidecar_path(plugin);
            if (!FileUtils.test(path, FileTest.EXISTS)) {
                return new Json.Object();
            }

            try {
                var parser = new Json.Parser();
                parser.load_from_file(path);
                var root = parser.get_root();
                if (root != null && root.get_node_type() == Json.NodeType.OBJECT) {
                    return root.get_object();
                }
            } catch (Error err) {
                log_service.warning(@"Failed to parse variable sidecar for $(plugin.filename): $(err.message)");
            }

            return new Json.Object();
        }

        private void save_sidecar_object(PluginDefinition plugin, Json.Object sidecar) {
            try {
                var root = new Json.Node(Json.NodeType.OBJECT);
                root.set_object(sidecar);

                var generator = new Json.Generator();
                generator.set_pretty(true);
                generator.set_root(root);
                string data = generator.to_data(null);
                FileUtils.set_contents(get_sidecar_path(plugin), data);
            } catch (Error err) {
                log_service.warning(@"Failed to save variable sidecar for $(plugin.filename): $(err.message)");
            }
        }

        private void set_member_value(
            Json.Object sidecar,
            PluginVariableDefinition definition,
            string raw_value
        ) {
            switch (definition.variable_type) {
            case PluginVariableType.NUMBER:
                int64 int_value;
                if (int64.try_parse(raw_value, out int_value)) {
                    sidecar.set_int_member(definition.name, int_value);
                    break;
                }

                double number_value;
                if (double.try_parse(raw_value, out number_value)) {
                    sidecar.set_double_member(definition.name, number_value);
                } else {
                    set_member_value(sidecar, definition, definition.default_value);
                }
                break;
            case PluginVariableType.BOOLEAN:
                sidecar.set_boolean_member(definition.name, raw_value.down() == "true");
                break;
            case PluginVariableType.SELECT:
                string selected = raw_value;
                if (definition.options.size > 0 && !definition.options.contains(selected)) {
                    selected = definition.default_value;
                }
                sidecar.set_string_member(definition.name, selected);
                break;
            case PluginVariableType.STRING:
            default:
                sidecar.set_string_member(definition.name, raw_value);
                break;
            }
        }

        private string get_environment_value(Json.Object sidecar, PluginVariableDefinition definition) {
            if (!sidecar.has_member(definition.name)) {
                return definition.default_value;
            }

            var node = sidecar.get_member(definition.name);
            if (node == null) {
                return definition.default_value;
            }

            switch (definition.variable_type) {
            case PluginVariableType.NUMBER:
                if (node.get_value_type() == typeof(int64)) {
                    return sidecar.get_int_member(definition.name).to_string();
                }

                if (node.get_value_type() == typeof(double)) {
                    return format_number(sidecar.get_double_member(definition.name));
                }

                return definition.default_value;
            case PluginVariableType.BOOLEAN:
                if (node.get_value_type() != typeof(bool)) {
                    return definition.default_value;
                }

                return sidecar.get_boolean_member(definition.name) ? "true" : "false";
            case PluginVariableType.SELECT:
                if (node.get_value_type() != typeof(string)) {
                    return definition.default_value;
                }

                string value = sidecar.get_string_member(definition.name);
                if (definition.options.size > 0 && !definition.options.contains(value)) {
                    return definition.default_value;
                }

                return value;
            case PluginVariableType.STRING:
            default:
                if (node.get_value_type() != typeof(string)) {
                    return definition.default_value;
                }

                return sidecar.get_string_member(definition.name);
            }
        }

        private string format_number(double value) {
            int64 integral_value = (int64) value;
            if ((double) integral_value == value) {
                return integral_value.to_string();
            }

            return value.to_string();
        }

        private string unquote(string value) {
            if (value.length >= 2 && value.has_prefix("\"") && value.has_suffix("\"")) {
                return value.substring(1, value.length - 2);
            }

            return value;
        }
    }
}
