int main(string[] args) {
    if (args.length > 1 && args[1] == "run") {
        var cli_runner = new Sidewing.CliRunner();
        return cli_runner.run_plugin_command(args);
    }

    var app = new Sidewing.Application();
    return app.run(args);
}
