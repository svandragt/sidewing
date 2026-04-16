namespace Staba {
    public class MonitorManager : Object {
        private LogService log_service;

        public MonitorManager(LogService log_service) {
            this.log_service = log_service;
        }

        public Gee.ArrayList<MonitorInfo> list_monitors() {
            var monitors = new Gee.ArrayList<MonitorInfo>();
            var display = Gdk.Display.get_default();

            if (display == null) {
                log_service.warning("No GDK display available");
                return monitors;
            }

            var total = display.get_monitors().get_n_items();
            for (uint i = 0; i < total; i++) {
                var object = display.get_monitors().get_item(i);
                var monitor = object as Gdk.Monitor;
                if (monitor == null) {
                    continue;
                }

                Gdk.Rectangle geometry = monitor.get_geometry();

                // GTK4 does not expose a primary-monitor getter here, so the first
                // reported monitor is used as the default primary candidate.
                bool primary = (i == 0);
                string connector = monitor.get_connector();
                string label = connector != null ? connector : @"Monitor $(i + 1)";
                monitors.add(new MonitorInfo(
                    @"monitor-$(i)",
                    label,
                    geometry.x,
                    geometry.y,
                    geometry.width,
                    geometry.height,
                    primary
                ));
            }

            return monitors;
        }

        public MonitorInfo? get_selected_monitor(string? configured_id) {
            var monitors = list_monitors();

            if (configured_id != null) {
                foreach (var monitor in monitors) {
                    if (monitor.id == configured_id) {
                        return monitor;
                    }
                }
            }

            foreach (var monitor in monitors) {
                if (!monitor.primary) {
                    return monitor;
                }
            }

            return monitors.size > 0 ? monitors[0] : null;
        }
    }
}
