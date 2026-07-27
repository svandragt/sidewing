using Sidewing;

private MonitorInfo secondary_monitor() {
    return new MonitorInfo(
        "connector:HDMI-A-0",
        "HDMI-A-0",
        "HDMI-A-0",
        1920,
        0,
        1920,
        1080,
        false
    );
}

private void test_exact_secondary_geometry_matches() {
    var monitor = secondary_monitor();

    assert_true(BarPlacement.matches(1920, 0, 1920, 32, monitor, 32));
}

private void test_primary_monitor_position_does_not_match() {
    var monitor = secondary_monitor();

    assert_false(BarPlacement.matches(0, 0, 1920, 32, monitor, 32));
}

private void test_wingpanel_height_offset_does_not_match() {
    var monitor = secondary_monitor();

    assert_false(BarPlacement.matches(1920, 32, 1920, 32, monitor, 32));
}

private void test_content_width_drift_does_not_match() {
    var monitor = secondary_monitor();

    assert_false(BarPlacement.matches(1920, 0, 1788, 32, monitor, 32));
}

private void test_visible_window_stays_managed() {
    assert_false(BarPlacement.visible_window_uses_override_redirect());
}

private int main(string[] args) {
    Test.init(ref args);
    Test.add_func("/bar-placement/exact-secondary-geometry", test_exact_secondary_geometry_matches);
    Test.add_func("/bar-placement/rejects-primary-position", test_primary_monitor_position_does_not_match);
    Test.add_func("/bar-placement/rejects-wingpanel-offset", test_wingpanel_height_offset_does_not_match);
    Test.add_func("/bar-placement/rejects-content-width", test_content_width_drift_does_not_match);
    Test.add_func("/bar-placement/visible-window-stays-managed", test_visible_window_stays_managed);
    return Test.run();
}
