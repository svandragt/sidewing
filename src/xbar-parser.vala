namespace Staba {
    public class XbarParser : Object {
        public ParsedPluginState parse(string stdout_text) {
            var state = new ParsedPluginState();
            var lines = stdout_text.split("\n");

            foreach (var line in lines) {
                var stripped = line.strip();
                if (stripped == "") {
                    continue;
                }

                state.items.add(new ParsedItem(ParsedItemKind.BAR_LINE, stripped));
                if (state.visible_title == "staba") {
                    state.visible_title = stripped;
                }
            }

            return state;
        }
    }
}
