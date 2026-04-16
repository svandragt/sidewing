namespace Staba {
    public class MenuBuilder : Object {
        private ActionDispatcher action_dispatcher;

        public MenuBuilder(ActionDispatcher action_dispatcher) {
            this.action_dispatcher = action_dispatcher;
        }

        public Gtk.Widget build_placeholder_menu(string title) {
            var popover = new Gtk.Popover();
            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
            box.margin_start = 12;
            box.margin_end = 12;
            box.margin_top = 12;
            box.margin_bottom = 12;

            var heading = new Gtk.Label(title);
            heading.halign = Gtk.Align.START;
            heading.add_css_class("heading");

            var details = new Gtk.Label("Plugin menu scaffolding");
            details.halign = Gtk.Align.START;

            box.append(heading);
            box.append(details);
            popover.set_child(box);

            return popover;
        }
    }
}
