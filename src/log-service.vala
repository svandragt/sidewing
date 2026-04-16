namespace Sidewing {
    public class LogService : Object {
        private Mutex write_mutex;

        public void info(string message) {
            log("INFO", message);
        }

        public void warning(string message) {
            log("WARN", message);
        }

        private void log(string level, string message) {
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
