namespace Staba {
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
                    if (state.visible_title == "staba") {
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
            bool disabled = false;

            foreach (string token in metadata.split(" ")) {
                string stripped = token.strip();
                if (stripped == "") {
                    continue;
                }

                var parts = stripped.split("=", 2);
                if (parts.length != 2) {
                    continue;
                }

                string key = parts[0].strip();
                string value = parts[1].strip().replace("\"", "");

                switch (key) {
                case "refresh":
                    refresh = value == "true";
                    break;
                case "href":
                    href = value;
                    break;
                case "disabled":
                    disabled = value == "true";
                    break;
                default:
                    break;
                }
            }

            return new ParsedItem(kind, content, depth, refresh, href, disabled);
        }
    }
}
