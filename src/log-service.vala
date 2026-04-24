namespace Sidewing {
    public class LogService : Object {
        private const int64 ROTATE_SIZE_BYTES = 1024 * 1024;

        private Mutex write_mutex;
        private string? log_file_path;
        private FileStream? log_file;
        public bool enabled { get; set; default = true; }

        public LogService(bool enabled = true, string? log_file_path = null) {
            this.enabled = enabled;
            this.log_file_path = log_file_path;
            open_log_file();
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

            string line = "[%s] [%s] %s".printf(timestamp(), level, message);

            write_mutex.lock();
            stdout.printf("%s\n", line);
            stdout.flush();
            if (log_file != null) {
                log_file.printf("%s\n", line);
                log_file.flush();
            }
            write_mutex.unlock();
        }

        private void open_log_file() {
            if (log_file_path == null) {
                return;
            }

            try {
                string directory = Path.get_dirname(log_file_path);
                DirUtils.create_with_parents(directory, 0755);
            } catch (Error err) {
                stderr.printf("Failed to create log directory: %s\n", err.message);
                return;
            }

            rotate_if_needed();

            log_file = FileStream.open(log_file_path, "a");
            if (log_file == null) {
                stderr.printf("Failed to open log file %s\n", log_file_path);
            }
        }

        private void rotate_if_needed() {
            if (!FileUtils.test(log_file_path, FileTest.EXISTS)) {
                return;
            }

            int64 size = 0;
            try {
                var info = File.new_for_path(log_file_path).query_info(
                    FileAttribute.STANDARD_SIZE,
                    FileQueryInfoFlags.NONE
                );
                size = info.get_size();
            } catch (Error err) {
                return;
            }

            if (size < ROTATE_SIZE_BYTES) {
                return;
            }

            string rotated = log_file_path + ".1";
            if (FileUtils.test(rotated, FileTest.EXISTS)) {
                FileUtils.remove(rotated);
            }
            FileUtils.rename(log_file_path, rotated);
        }

        private string timestamp() {
            var now = new DateTime.now_local();
            return now.format("%H:%M:%S.%f");
        }
    }
}
