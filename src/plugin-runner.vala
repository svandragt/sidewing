namespace Sidewing {
    public class PluginRunner : Object {
        private LogService log_service;
        private VariablesStore variables_store;
        private SettingsStore settings_store;
        private string? login_shell_path;
        private bool login_shell_path_resolved = false;
        private Mutex path_mutex;

        public PluginRunner(LogService log_service, VariablesStore variables_store, SettingsStore settings_store) {
            this.log_service = log_service;
            this.variables_store = variables_store;
            this.settings_store = settings_store;
        }

        public PluginRunResult run(PluginDefinition plugin) {
            log_service.info(@"Running plugin $(plugin.filename)");

            try {
                var launcher = new SubprocessLauncher(SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                string plugin_dir = Path.get_dirname(plugin.path);

                launcher.set_cwd(plugin_dir);
                launcher.setenv("SIDEWING", "1", true);
                launcher.setenv("XBAR", "1", true);
                launcher.setenv("SIDEWING_PLUGIN_PATH", plugin.path, true);
                launcher.setenv("SIDEWING_PLUGIN_DIR", settings_store.plugins_dir, true);
                apply_shell_path_to_launcher(launcher);
                variables_store.apply_to_launcher(launcher, plugin);
                log_plugin_environment(plugin);

                string[] argv = { plugin.path, null };
                var process = launcher.spawnv(argv);

                string? stdout_text = null;
                string? stderr_text = null;
                process.communicate_utf8(null, null, out stdout_text, out stderr_text);

                return new PluginRunResult(
                    stdout_text ?? "",
                    stderr_text ?? "",
                    process.get_exit_status(),
                    false
                );
            } catch (Error err) {
                log_service.warning(@"Plugin run failed for $(plugin.filename): $(err.message)");
                return new PluginRunResult(
                    "",
                    err.message,
                    1,
                    false,
                    err.message.contains("No such file or directory")
                );
            }
        }

        private void apply_shell_path_to_launcher(SubprocessLauncher launcher) {
            string? resolved_path = get_login_shell_path();
            if (resolved_path == null || resolved_path == "") {
                return;
            }

            launcher.setenv("PATH", resolved_path, true);
        }

        private void log_plugin_environment(PluginDefinition plugin) {
            string? path = get_login_shell_path();
            if (path == null || path == "") {
                log_service.warning(@"Launching $(plugin.filename) without a resolved PATH");
                return;
            }

            log_service.info(@"Launching $(plugin.filename) with PATH=$(path)");

            if (plugin.filename.contains("github") || plugin.filename.contains("gh")) {
                log_command_resolution(plugin, path, "gh");
            }
        }

        private void log_command_resolution(PluginDefinition plugin, string path, string command) {
            string shell_path = Environment.get_variable("SHELL") ?? "/bin/sh";
            string quoted_path = Shell.quote(path);
            string quoted_command = Shell.quote(command);
            string[] argv = {
                shell_path,
                "-lc",
                "PATH=" + quoted_path + "; command -v " + quoted_command,
                null
            };

            try {
                string stdout_text;
                string stderr_text;
                int wait_status;
                Process.spawn_sync(
                    null,
                    argv,
                    null,
                    SpawnFlags.SEARCH_PATH,
                    null,
                    out stdout_text,
                    out stderr_text,
                    out wait_status
                );

                if (Process.if_exited(wait_status) && Process.exit_status(wait_status) == 0) {
                    string resolved = stdout_text.strip();
                    log_service.info(@"$(plugin.filename) resolved $(command) to $(resolved)");
                    return;
                }

                if (stderr_text != null && stderr_text.strip() != "") {
                    log_service.warning(@"$(plugin.filename) failed resolving $(command): $(stderr_text.strip())");
                } else {
                    log_service.warning(@"$(plugin.filename) could not resolve $(command) on PATH");
                }
            } catch (SpawnError err) {
                log_service.warning(@"$(plugin.filename) failed resolving $(command): $(err.message)");
            }
        }

        private string? get_login_shell_path() {
            path_mutex.lock();
            if (login_shell_path_resolved) {
                path_mutex.unlock();
                return login_shell_path;
            }

            login_shell_path_resolved = true;

            string shell_path = Environment.get_variable("SHELL") ?? "/bin/sh";
            var candidates = new Gee.ArrayList<string>();

            add_path_candidate(candidates, Environment.get_variable("PATH"));
            add_path_candidate(candidates, resolve_path_command(
                shell_path,
                "-lc",
                "printf %s \"$PATH\"",
                "login shell"
            ));
            add_path_candidate(candidates, resolve_path_command(
                shell_path,
                "-ic",
                "printf %s \"$PATH\"",
                "interactive shell"
            ));
            add_path_candidate(candidates, resolve_path_command(
                "/bin/sh",
                "-lc",
                "[ -f \"$HOME/.profile\" ] && . \"$HOME/.profile\" >/dev/null 2>&1; printf %s \"$PATH\"",
                ".profile"
            ));

            login_shell_path = merge_path_candidates(candidates);
            if (login_shell_path != null && login_shell_path != "") {
                log_service.info(@"Resolved plugin PATH from environment/profile: $(login_shell_path)");
            } else {
                log_service.warning("Failed to resolve plugin PATH from environment/profile");
            }

            path_mutex.unlock();
            return login_shell_path;
        }

        private string? resolve_path_command(string shell_path, string shell_flag, string script, string source_name) {
            string[] argv = { shell_path, shell_flag, script, null };

            try {
                string stdout_text;
                string stderr_text;
                int wait_status;
                Process.spawn_sync(
                    null,
                    argv,
                    null,
                    SpawnFlags.SEARCH_PATH,
                    null,
                    out stdout_text,
                    out stderr_text,
                    out wait_status
                );

                if (Process.if_exited(wait_status) && Process.exit_status(wait_status) == 0) {
                    string candidate = stdout_text.strip();
                    if (candidate != "") {
                        return candidate;
                    }
                }

                if (stderr_text != null && stderr_text.strip() != "") {
                    log_service.warning(@"Failed to resolve PATH from $(source_name): $(stderr_text.strip())");
                }
            } catch (SpawnError err) {
                log_service.warning(@"Failed to resolve PATH from $(source_name): $(err.message)");
            }

            return null;
        }

        private void add_path_candidate(Gee.ArrayList<string> candidates, string? candidate) {
            if (candidate == null) {
                return;
            }

            string stripped = candidate.strip();
            if (stripped == "") {
                return;
            }

            candidates.add(stripped);
        }

        private string? merge_path_candidates(Gee.ArrayList<string> candidates) {
            var segments = new Gee.ArrayList<string>();

            foreach (string candidate in candidates) {
                foreach (string segment in candidate.split(":")) {
                    string stripped = segment.strip();
                    if (stripped == "") {
                        continue;
                    }

                    if (!segments.contains(stripped)) {
                        segments.add(stripped);
                    }
                }
            }

            if (segments.size == 0) {
                return null;
            }

            var builder = new StringBuilder();
            bool first = true;
            foreach (string segment in segments) {
                if (!first) {
                    builder.append(":");
                }

                builder.append(segment);
                first = false;
            }

            return builder.str;
        }
    }
}
