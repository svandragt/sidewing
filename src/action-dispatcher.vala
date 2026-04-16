namespace Sidewing {
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
    }
}
