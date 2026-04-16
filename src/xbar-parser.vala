namespace Sidewing {
    public class XbarParser : Object {
        public ParsedPluginState parse(string stdout_text) {
            var state = new ParsedPluginState();
            var lines = stdout_text.split("\n");
            bool in_menu = false;

            foreach (var line in lines) {
                var stripped = line.strip();
                if (stripped == "") {
                    continue;
                }

                if (stripped == "---") {
                    in_menu = true;
                    if (state.menu_items.size > 0) {
                        state.menu_items.add(new ParsedItem(ParsedItemKind.SEPARATOR, ""));
                    }
                    continue;
                }

                var item = parse_item(stripped, in_menu ? ParsedItemKind.MENU_ITEM : ParsedItemKind.BAR_LINE);
                if (in_menu) {
                    state.menu_items.add(item);
                } else {
                    state.bar_items.add(item);
                    if (state.visible_title == "Sidewing") {
                        state.visible_title = item.title;
                    }
                }
            }

            return state;
        }

        private ParsedItem parse_item(string line, ParsedItemKind kind) {
            string content = line;
            string metadata = "";
            int pipe_index = line.index_of("|");
            if (pipe_index >= 0) {
                content = line.substring(0, pipe_index).strip();
                metadata = line.substring(pipe_index + 1).strip();
            }

            uint depth = 0;
            if (kind == ParsedItemKind.MENU_ITEM) {
                while (content.has_prefix("--")) {
                    depth++;
                    content = content.substring(2).strip();
                }
            }

            bool refresh = false;
            string? href = null;
            string? shell_command = null;
            var shell_params = new Gee.TreeMap<int, string>();
            bool terminal = false;
            bool disabled = false;

            foreach (string token in tokenize_metadata(metadata)) {
                if (token == "") {
                    continue;
                }

                var parts = token.split("=", 2);
                if (parts.length != 2) {
                    continue;
                }

                string key = parts[0].strip();
                string value = unquote(parts[1].strip());

                switch (key) {
                case "refresh":
                    refresh = value == "true";
                    break;
                case "href":
                    href = value;
                    break;
                case "shell":
                    shell_command = value;
                    break;
                case "terminal":
                    terminal = value == "true";
                    break;
                case "disabled":
                    disabled = value == "true";
                    break;
                default:
                    if (key.has_prefix("param")) {
                        int index = int.parse(key.substring(5));
                        if (index > 0) {
                            shell_params.set(index, value);
                        }
                    }
                    break;
                }
            }

            var ordered_params = new Gee.ArrayList<string>();
            foreach (var param in shell_params.entries) {
                ordered_params.add(param.value);
            }

            return new ParsedItem(
                kind,
                content,
                depth,
                refresh,
                href,
                shell_command,
                ordered_params,
                terminal,
                disabled
            );
        }

        private Gee.ArrayList<string> tokenize_metadata(string metadata) {
            var tokens = new Gee.ArrayList<string>();
            var current = new StringBuilder();
            bool in_quotes = false;

            for (int i = 0; i < metadata.length; i++) {
                unichar ch = metadata.get_char(i);
                if (ch == '"') {
                    in_quotes = !in_quotes;
                    current.append_unichar(ch);
                    continue;
                }

                if (!in_quotes && ch.isspace()) {
                    if (current.len > 0) {
                        tokens.add(current.str);
                        current = new StringBuilder();
                    }
                    continue;
                }

                current.append_unichar(ch);
            }

            if (current.len > 0) {
                tokens.add(current.str);
            }

            return tokens;
        }

        private string unquote(string value) {
            if (value.length >= 2 && value.has_prefix("\"") && value.has_suffix("\"")) {
                return value.substring(1, value.length - 2);
            }

            return value;
        }
    }
}
