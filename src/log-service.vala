namespace Sidewing {
    public class LogService : Object {
        private Mutex write_mutex;
        public bool enabled { get; set; default = true; }

        public LogService(bool enabled = true) {
            this.enabled = enabled;
        }

        public void info(string message) {
            log("INFO", message);
        }

        public void warning(string message) {
            log("WARN", message);
        }

        private void log(string level, string message) {
            if (!enabled) {
                return;
            }

            write_mutex.lock();
            stdout.printf("[%s] [%s] %s\n", timestamp(), level, message);
            stdout.flush();
            write_mutex.unlock();
        }

        private string timestamp() {
            var now = new DateTime.now_local();
            return now.format("%H:%M:%S.%f");
        }
    }
}
