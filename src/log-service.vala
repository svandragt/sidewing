namespace Staba {
    public class LogService : Object {
        public void info(string message) {
            stdout.printf("[INFO] %s\n", message);
        }

        public void warning(string message) {
            stdout.printf("[WARN] %s\n", message);
        }
    }
}
