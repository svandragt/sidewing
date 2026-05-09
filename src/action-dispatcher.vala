namespace Sidewing {
    public delegate void ActionCompletion();

    public class ActionDispatcher : Object {
        private Gtk.Application application;
        private LogService log_service;

        public ActionDispatcher(Gtk.Application application, LogService log_service) {
            this.application = application;
            this.log_service = log_service;
        }

        public void open_uri(string uri) {
            try {
                AppInfo.launch_default_for_uri(uri, null);
                log_service.info(@"Opened URI: $uri");
            } catch (Error err) {
                log_service.warning(@"Failed to open URI $uri: $(err.message)");
            }
        }

        public void open_directory(string path) {
            var directory = File.new_for_path(path);
            open_uri(directory.get_uri());
        }

        public void execute_command(
            string command,
            Gee.List<string> arguments,
            string working_directory,
            bool terminal_requested = false,
            owned ActionCompletion? on_complete = null
        ) {
            if (terminal_requested) {
                if (launch_in_terminal(command, arguments, working_directory)) {
                    if (on_complete != null) {
                        Idle.add(() => {
                            on_complete();
                            return Source.REMOVE;
                        });
                    }
                    return;
                }
                log_service.warning(@"No terminal emulator found; executing $command without a terminal");
            }

            new Thread<int>(@"action-$(Path.get_basename(command))", () => {
                try {
                    var launcher = new SubprocessLauncher(SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_PIPE);
                    launcher.set_cwd(working_directory);

                    string[] argv = new string[arguments.size + 2];
                    argv[0] = command;
                    int i = 1;
                    foreach (var argument in arguments) {
                        argv[i++] = argument;
                    }
                    argv[i] = null;

                    var process = launcher.spawnv(argv);
                    string? stdout_text = null;
                    string? stderr_text = null;
                    process.communicate_utf8(null, null, out stdout_text, out stderr_text);

                    if (process.get_exit_status() == 0) {
                        log_service.info(@"Executed command: $command");
                    } else {
                        var stderr_message = (stderr_text ?? "").strip();
                        if (stderr_message != "") {
                            log_service.warning(@"Command failed: $command ($(stderr_message))");
                        } else {
                            log_service.warning(@"Command failed: $command (exit $(process.get_exit_status()))");
                        }
                    }
                } catch (Error err) {
                    log_service.warning(@"Failed to execute command $command: $(err.message)");
                }

                if (on_complete != null) {
                    Idle.add(() => {
                        on_complete();
                        return Source.REMOVE;
                    });
                }

                return 0;
            });
        }

        private bool launch_in_terminal(
            string command,
            Gee.List<string> arguments,
            string working_directory
        ) {
            var shell_cmd = new StringBuilder();
            shell_cmd.append(Shell.quote(command));
            foreach (var arg in arguments) {
                shell_cmd.append(" ");
                shell_cmd.append(Shell.quote(arg));
            }
            shell_cmd.append("; status=$?; printf '\\n[exit %s — press Enter to close] ' \"$status\"; read _");

            string[] candidates = {};
            string? user_term = Environment.get_variable("TERMINAL");
            if (user_term != null && user_term != "") {
                candidates += user_term;
            }
            string[] fallbacks = {
                "x-terminal-emulator", "gnome-terminal", "konsole",
                "xfce4-terminal", "alacritty", "kitty", "wezterm",
                "foot", "tilix", "xterm"
            };
            foreach (var t in fallbacks) {
                candidates += t;
            }

            foreach (var term in candidates) {
                string? path = Environment.find_program_in_path(term);
                if (path == null) {
                    continue;
                }
                string[] argv = build_terminal_argv(term, path, shell_cmd.str);
                try {
                    var launcher = new SubprocessLauncher(SubprocessFlags.NONE);
                    launcher.set_cwd(working_directory);
                    launcher.spawnv(argv);
                    log_service.info(@"Executed in terminal ($term): $command");
                    return true;
                } catch (Error err) {
                    log_service.warning(@"Failed to launch terminal $term: $(err.message)");
                }
            }
            return false;
        }

        private string[] build_terminal_argv(string term, string path, string shell_cmd) {
            string name = Path.get_basename(term);
            switch (name) {
                case "gnome-terminal":
                case "tilix":
                    return { path, "--", "sh", "-c", shell_cmd, null };
                case "wezterm":
                    return { path, "start", "--", "sh", "-c", shell_cmd, null };
                case "kitty":
                case "foot":
                    return { path, "sh", "-c", shell_cmd, null };
                case "xfce4-terminal":
                    return { path, "-x", "sh", "-c", shell_cmd, null };
                default:
                    return { path, "-e", "sh", "-c", shell_cmd, null };
            }
        }
    }
}
