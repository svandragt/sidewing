namespace Sidewing {
    public class PluginManager : Object {
        private SettingsStore settings_store;
        private PluginRunner plugin_runner;
        private XbarParser xbar_parser;
        private LogService log_service;
        private Gee.ArrayList<PluginRecord> plugin_records;

        public signal void plugins_changed();
        public signal void plugin_updated(PluginRecord record);

        public PluginManager(
            SettingsStore settings_store,
            PluginRunner plugin_runner,
            XbarParser xbar_parser,
            LogService log_service
        ) {
            this.settings_store = settings_store;
            this.plugin_runner = plugin_runner;
            this.xbar_parser = xbar_parser;
            this.log_service = log_service;
            plugin_records = new Gee.ArrayList<PluginRecord>();
        }

        public Gee.ArrayList<PluginRecord> get_records() {
            return plugin_records;
        }

        public void start() {
            log_service.info("Plugin manager start");
            stop();
            discover_plugins();
            plugins_changed();
            queue_initial_refresh();
            schedule_refreshes();
        }

        public void stop() {
            log_service.info("Plugin manager stop");
            foreach (var record in plugin_records) {
                if (record.refresh_source_id != 0) {
                    Source.remove(record.refresh_source_id);
                    record.refresh_source_id = 0;
                }
            }
        }

        public void refresh_all() {
            log_service.info(@"Refreshing all plugins ($(plugin_records.size))");
            foreach (var record in plugin_records) {
                refresh_record(record);
            }
        }

        public void refresh_record(PluginRecord record) {
            if (record.run_in_progress) {
                log_service.info(@"Refresh already running for $(record.definition.filename); queueing another refresh");
                record.refresh_queued = true;
                return;
            }

            record.run_in_progress = true;
            record.refresh_queued = false;
            log_service.info(@"Dispatching async refresh for $(record.definition.filename)");

            new Thread<int>(@"refresh-$(record.definition.filename)", () => {
                var result = plugin_runner.run(record.definition);

                Idle.add(() => {
                    apply_run_result(record, result);
                    return Source.REMOVE;
                });

                return 0;
            });
        }

        private void discover_plugins() {
            log_service.info(@"Discovering plugins in $(settings_store.plugins_dir)");
            plugin_records.clear();
            var directory = File.new_for_path(settings_store.plugins_dir);

            try {
                var enumerator = directory.enumerate_children(
                    FileAttribute.STANDARD_NAME + "," +
                    FileAttribute.STANDARD_TYPE + "," +
                    FileAttribute.UNIX_MODE,
                    FileQueryInfoFlags.NONE
                );

                FileInfo? info;
                while ((info = enumerator.next_file()) != null) {
                    if (info.get_file_type() != FileType.REGULAR) {
                        continue;
                    }

                    string filename = info.get_name();
                    if (!is_executable(info)) {
                        continue;
                    }

                    uint refresh_seconds = parse_refresh_seconds(filename);
                    if (refresh_seconds == 0) {
                        continue;
                    }

                    var child = directory.get_child(filename);
                    var definition = new PluginDefinition(
                        child.get_path(),
                        filename,
                        build_display_name(filename),
                        refresh_seconds
                    );
                    plugin_records.add(new PluginRecord(definition));
                    log_service.info(@"Discovered plugin $(filename) ($(refresh_seconds)s)");
                }
            } catch (Error err) {
                log_service.warning(@"Plugin discovery failed: $(err.message)");
            }

            plugin_records.sort((a, b) => {
                return strcmp(a.definition.filename, b.definition.filename);
            });
            log_service.info(@"Plugin discovery complete: $(plugin_records.size) plugins");
        }

        private void schedule_refreshes() {
            foreach (var record in plugin_records) {
                log_service.info(@"Scheduling $(record.definition.filename) every $(record.definition.refresh_seconds)s");
                record.refresh_source_id = Timeout.add_seconds(record.definition.refresh_seconds, () => {
                    log_service.info(@"Timer fired for $(record.definition.filename)");
                    refresh_record(record);
                    return Source.CONTINUE;
                });
            }
        }

        private void queue_initial_refresh() {
            Idle.add(() => {
                log_service.info("Initial refresh idle callback start");
                refresh_all();
                log_service.info("Initial refresh idle callback end");
                return Source.REMOVE;
            });
        }

        private void apply_run_result(PluginRecord record, PluginRunResult result) {
            var state = xbar_parser.parse(result.stdout_text);

            if (state.visible_title == "Sidewing" || state.visible_title == "") {
                state.visible_title = record.definition.display_name;
            }

            state.stderr_text = result.stderr_text;
            if (result.exit_code != 0) {
                state.warnings.add(@"Plugin exited with status $(result.exit_code)");
            }

            if (result.stderr_text != "") {
                state.warnings.add(result.stderr_text.strip());
            }

            record.state = state;
            record.run_in_progress = false;
            plugin_updated(record);

            if (record.refresh_queued) {
                log_service.info(@"Running queued refresh for $(record.definition.filename)");
                record.refresh_queued = false;
                refresh_record(record);
            }
        }

        private bool is_executable(FileInfo info) {
            uint32 mode = info.get_attribute_uint32(FileAttribute.UNIX_MODE);
            return (mode & 0111) != 0;
        }

        private string build_display_name(string filename) {
            try {
                var regex = new Regex("""^(.*)\.[0-9]+[smhd]\.[^.]+$""");
                MatchInfo info;
                if (regex.match(filename, 0, out info)) {
                    return info.fetch(1);
                }
            } catch (Error err) {
                log_service.warning(@"Failed to build display name for $(filename): $(err.message)");
            }

            return filename;
        }

        private uint parse_refresh_seconds(string filename) {
            try {
                var regex = new Regex(""".*\.([0-9]+)([smhd])\.[^.]+$""");
                MatchInfo info;
                if (!regex.match(filename, 0, out info)) {
                    return 0;
                }

                uint value = uint.parse(info.fetch(1));
                switch (info.fetch(2)) {
                case "s":
                    return value;
                case "m":
                    return value * 60;
                case "h":
                    return value * 60 * 60;
                case "d":
                    return value * 60 * 60 * 24;
                default:
                    return 0;
                }
            } catch (Error err) {
                log_service.warning(@"Failed to parse plugin interval: $(err.message)");
                return 0;
            }
        }
    }
}
