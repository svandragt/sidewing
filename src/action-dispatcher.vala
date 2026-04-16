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
                log_service.warning(@"terminal=true is not supported yet; executing $command without a terminal");
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
    }
}
