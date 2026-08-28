int main(string[] args) {
    if (args.length > 1 && args[1] == "run") {
        var cli_runner = new Sidewing.CliRunner();
        return cli_runner.run_plugin_command(args);
    }

    if (args.length > 1 && args[1] == "reload") {
        var running = new Sidewing.Application();
        try {
            running.register();
        } catch (Error err) {
            stderr.printf("Failed to contact Sidewing: %s\n", err.message);
            return 1;
        }
        if (!running.get_is_remote()) {
            stderr.printf("Sidewing is not running\n");
            return 1;
        }
        running.activate_action("reload", null);
        // Drain the outgoing D-Bus message before we exit.
        var ctx = GLib.MainContext.default();
        while (ctx.pending()) {
            ctx.iteration(false);
        }
        return 0;
    }

    var app = new Sidewing.Application();
    return app.run(args);
}
