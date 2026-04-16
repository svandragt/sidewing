namespace Sidewing {
    public class LogService : Object {
        public void info(string message) {
            stdout.printf("[%s] [INFO] %s\n", timestamp(), message);
        }

        public void warning(string message) {
            stdout.printf("[%s] [WARN] %s\n", timestamp(), message);
        }

        private string timestamp() {
            var now = new DateTime.now_local();
            return now.format("%H:%M:%S.%f");
        }
    }
}
