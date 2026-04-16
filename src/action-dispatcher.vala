namespace Staba {
    public class ActionDispatcher : Object {
        private Gtk.Application application;
        private LogService log_service;

        public ActionDispatcher(Gtk.Application application, LogService log_service) {
            this.application = application;
            this.log_service = log_service;
        }

        public void open_uri(string uri) {
            log_service.info(@"Requested URI open: $uri");
        }
    }
}
