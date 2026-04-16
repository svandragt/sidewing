namespace Staba {
    public enum ParsedItemKind {
        BAR_LINE,
        MENU_ITEM,
        SEPARATOR
    }

    public class MonitorInfo : Object {
        public string id { get; construct set; }
        public string display_name { get; construct set; }
        public string? connector { get; construct set; }
        public int x { get; construct set; }
        public int y { get; construct set; }
        public int width { get; construct set; }
        public int height { get; construct set; }
        public bool primary { get; construct set; }

        public MonitorInfo(
            string id,
            string display_name,
            string? connector,
            int x,
            int y,
            int width,
            int height,
            bool primary
        ) {
            Object(
                id: id,
                display_name: display_name,
                connector: connector,
                x: x,
                y: y,
                width: width,
                height: height,
                primary: primary
            );
        }
    }

    public class PluginDefinition : Object {
        public string path { get; construct set; }
        public string filename { get; construct set; }
        public string display_name { get; construct set; }
        public uint refresh_seconds { get; construct set; }
        public bool enabled { get; set; default = true; }

        public PluginDefinition(string path, string filename, string display_name, uint refresh_seconds) {
            Object(
                path: path,
                filename: filename,
                display_name: display_name,
                refresh_seconds: refresh_seconds
            );
        }
    }

    public class PluginRunResult : Object {
        public string stdout_text { get; construct set; }
        public string stderr_text { get; construct set; }
        public int exit_code { get; construct set; }
        public bool timed_out { get; construct set; }

        public PluginRunResult(string stdout_text = "", string stderr_text = "", int exit_code = 0, bool timed_out = false) {
            Object(
                stdout_text: stdout_text,
                stderr_text: stderr_text,
                exit_code: exit_code,
                timed_out: timed_out
            );
        }
    }

    public class ParsedItem : Object {
        public ParsedItemKind kind { get; construct set; }
        public string title { get; construct set; }
        public uint depth { get; construct set; }
        public bool refresh { get; construct set; }
        public string? href { get; construct set; }
        public bool disabled { get; construct set; }

        public ParsedItem(
            ParsedItemKind kind,
            string title,
            uint depth = 0,
            bool refresh = false,
            string? href = null,
            bool disabled = false
        ) {
            Object(
                kind: kind,
                title: title,
                depth: depth,
                refresh: refresh,
                href: href,
                disabled: disabled
            );
        }
    }

    public class ParsedPluginState : Object {
        public string visible_title { get; set; default = "staba"; }
        public Gee.ArrayList<ParsedItem> bar_items { get; private set; }
        public Gee.ArrayList<ParsedItem> menu_items { get; private set; }
        public Gee.ArrayList<string> warnings { get; private set; }
        public string stderr_text { get; set; default = ""; }

        public ParsedPluginState() {
            bar_items = new Gee.ArrayList<ParsedItem>();
            menu_items = new Gee.ArrayList<ParsedItem>();
            warnings = new Gee.ArrayList<string>();
        }
    }

    public class PluginRecord : Object {
        public PluginDefinition definition { get; construct set; }
        public ParsedPluginState state { get; set; }
        public uint refresh_source_id { get; set; default = 0; }

        public PluginRecord(PluginDefinition definition) {
            Object(
                definition: definition,
                state: new ParsedPluginState()
            );
        }
    }
}
