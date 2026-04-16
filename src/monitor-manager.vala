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
            int primary_candidate_index = get_primary_candidate_index(display);

            for (uint i = 0; i < total; i++) {
                var object = display.get_monitors().get_item(i);
                var monitor = object as Gdk.Monitor;
                if (monitor == null) {
                    continue;
                }

                Gdk.Rectangle geometry = monitor.get_geometry();
                string? connector = monitor.get_connector();
                string? description = monitor.get_description();
                bool primary = ((int) i == primary_candidate_index);
                string label = connector != null ? connector : (
                    description != null ? description : @"Monitor $(i + 1)"
                );

                monitors.add(new MonitorInfo(
                    build_monitor_id(connector, description, geometry, i),
                    label,
                    connector,
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
                    if (monitor_matches_id(monitor, configured_id)) {
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

        private int get_primary_candidate_index(Gdk.Display display) {
            var x11_display = display as Gdk.X11.Display;
            if (x11_display != null) {
                var primary_monitor = x11_display.get_primary_monitor();
                var total = display.get_monitors().get_n_items();
                for (uint i = 0; i < total; i++) {
                    var object = display.get_monitors().get_item(i);
                    var monitor = object as Gdk.Monitor;
                    if (monitor == primary_monitor) {
                        return (int) i;
                    }
                }
            }

            int selected_index = 0;
            int smallest_distance = int.MAX;
            var total = display.get_monitors().get_n_items();

            for (uint i = 0; i < total; i++) {
                var object = display.get_monitors().get_item(i);
                var monitor = object as Gdk.Monitor;
                if (monitor == null) {
                    continue;
                }

                Gdk.Rectangle geometry = monitor.get_geometry();
                int distance = absolute_value(geometry.x) + absolute_value(geometry.y);
                if (distance < smallest_distance) {
                    smallest_distance = distance;
                    selected_index = (int) i;
                }
            }

            return selected_index;
        }

        private string build_monitor_id(string? connector, string? description, Gdk.Rectangle geometry, uint index) {
            if (connector != null && connector != "") {
                return "connector:" + connector;
            }

            if (description != null && description != "") {
                return @"description:$(description)";
            }

            return @"geometry:$(geometry.width)x$(geometry.height)+$(geometry.x)+$(geometry.y):$(index)";
        }

        private bool monitor_matches_id(MonitorInfo monitor, string configured_id) {
            if (monitor.id == configured_id) {
                return true;
            }

            if (monitor.connector != null && configured_id == "connector:" + monitor.connector) {
                return true;
            }

            return false;
        }

        private int absolute_value(int value) {
            return value < 0 ? -value : value;
        }
    }
}
