namespace Sidewing {
    public class BarPlacement {
        public static bool visible_window_uses_override_redirect() {
            return false;
        }

        public static bool matches(
            int actual_x,
            int actual_y,
            int actual_width,
            int actual_height,
            MonitorInfo monitor,
            int bar_height
        ) {
            return actual_x == monitor.x
                && actual_y == monitor.y
                && actual_width == monitor.width
                && actual_height == bar_height;
        }
    }
}
