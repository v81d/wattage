/* window.vala
 *
 * Copyright 2025 v81d
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

using GLib;
using DeviceManager;

/* Define the class `DeviceRow`, which inherits from `Gtk.ListBoxRow`.
 * Use as a constructor for a single row in the device list sidebar.
 */
private class DeviceRow : Gtk.ListBoxRow {
    public DeviceObject device { get; private set; }

    public DeviceRow (DeviceObject device) {
        this.device = device;

        Adw.ActionRow row = new Adw.ActionRow ();
        row.set_title (device.native_path);
        row.set_subtitle (device.object_path);

        // Due to the deprecation of `row.icon_name` and `row.set_icon_name ()`, the icon should be prepended as a widget
        Gtk.Image icon = new Gtk.Image.from_icon_name (device.icon_name);
        icon.set_pixel_size (24);
        row.add_prefix (icon);

        this.set_child (row);
    }
}

/* This class inherits from `Gtk.Box`.
 * Use as a constructor for a single section in the device information view.
 */
private class DeviceInfoSection : Gtk.Box {
    public string title { get; private set; }
    private Gtk.ListBox list { private get; private set; }

    public DeviceInfoSection (string title, Gee.ArrayList<DeviceInfoSectionData.DeviceProperty> properties) {
        this.title = title;
        this.set_orientation (Gtk.Orientation.VERTICAL);
        this.set_spacing (12);

        Gtk.Label label = new Gtk.Label (title);
        label.set_halign (Gtk.Align.START);
        label.add_css_class ("title-2");
        this.append (label);

        this.list = new Gtk.ListBox ();
        this.list.set_selection_mode (Gtk.SelectionMode.NONE);
        this.list.set_hexpand (true);
        this.list.add_css_class ("boxed-list");
        this.append (this.list);

        this.update (properties);
    }

    public void update (Gee.ArrayList<DeviceInfoSectionData.DeviceProperty> properties) {
        Gtk.ListBoxRow? row;
        while ((row = this.list.get_row_at_index (0)) != null) {
            this.list.remove (row);
        }

        foreach (DeviceInfoSectionData.DeviceProperty property in properties) {
            Adw.ActionRow action_row = new Adw.ActionRow ();
            action_row.set_title (property.name);
            action_row.set_subtitle (property.value);
            action_row.set_subtitle_selectable (true);
            action_row.set_css_classes ({ "property", "monospace" });
            this.list.append (action_row);
        }
    }
}

private class DeviceInfoSectionData {
    public class DeviceProperty {
        public string name { get; set; }
        public string value { get; set; }

        public DeviceProperty (string name, string value) {
            this.name = name;
            this.value = value;
        }
    }

    public string title { get; private set; }
    public Gee.ArrayList<DeviceProperty> properties { get; private set; }

    public DeviceInfoSectionData (string title) {
        this.title = title;
        this.properties = new Gee.ArrayList<DeviceProperty> ();
    }

    public void set (string name, string? value) {
        if (value != null) {
            this.properties.add (new DeviceProperty (name, value));
        }
    }
}

[GtkTemplate (ui = "/io/github/v81d/Wattage/window.ui")]
public class Wattage.Window : Adw.ApplicationWindow {
    // Bind template children to variables
    [GtkChild] unowned Adw.Spinner sidebar_spinner;
    [GtkChild] unowned Adw.Spinner content_spinner;
    [GtkChild] unowned Adw.OverlaySplitView split_view;
    [GtkChild] unowned Gtk.ListBox device_list;
    [GtkChild] unowned Gtk.Box device_info_box;
    [GtkChild] unowned Adw.StatusPage device_list_empty_status;
    [GtkChild] unowned Adw.StatusPage device_info_empty_status;

    private Gtk.Builder preferences_dialog_builder;
    private GLib.Settings settings;

    private DeviceProber device_prober;
    private int selected_device_index = 0;
    private Gee.ArrayList<DeviceInfoSection> device_info_sections = new Gee.ArrayList<DeviceInfoSection> ();

    // Preferences and user settings
    private bool auto_refresh;
    private int auto_refresh_cooldown;
    private uint auto_refresh_source_id = 0;
    private string energy_unit;
    private string power_unit;
    private string voltage_unit;

    public Window (Gtk.Application app) {
        Object (application: app);

        this.device_prober = new DeviceProber ();
        this.load_device_list ();

        // This is the handler for selecting a device in the sidebar
        this.device_list.row_selected.connect ((list, row) => {
            if (row != null) {
                DeviceRow? device_row = row as DeviceRow;
                if (device_row != null) {
                    Adw.ActionRow? action_row = device_row.get_child () as Adw.ActionRow;
                    if (action_row != null) {
                        Idle.add (() => {
                            this.selected_device_index = device_row.get_index ();
                            this.device_info_empty_status.set_visible (false);
                            this.load_device_info (device_row.device);
                            return false;
                        });
                    }
                }
            }
        });

        this.initialize_gsettings ();
        this.initialize_preferences_dialog ();
    }

    construct {
        SimpleAction preferences_action = new SimpleAction ("preferences", null);
        preferences_action.activate.connect (this.on_preferences_action);
        this.add_action (preferences_action);

        SimpleAction refresh_action = new SimpleAction ("refresh", null);
        refresh_action.activate.connect (this.on_refresh_action);
        this.add_action (refresh_action);

        SimpleAction select_next_device_action = new SimpleAction ("select_next_device", null);
        select_next_device_action.activate.connect (this.on_select_next_device_action);
        this.add_action (select_next_device_action);

        SimpleAction select_previous_device_action = new SimpleAction ("select_previous_device", null);
        select_previous_device_action.activate.connect (this.on_select_previous_device_action);
        this.add_action (select_previous_device_action);
    }

    private void start_auto_refresh () {
        if (this.auto_refresh && this.auto_refresh_source_id == 0) {
            this.auto_refresh_source_id = Timeout.add_seconds (this.auto_refresh_cooldown, () => {
                if (this.auto_refresh) {
                    this.load_device_list ();
                    return true;
                } else {
                    this.auto_refresh_source_id = 0;
                    return false;
                }
            });
        }
    }

    private void stop_auto_refresh () {
        if (this.auto_refresh_source_id != 0) {
            Source.remove (this.auto_refresh_source_id);
            this.auto_refresh_source_id = 0;
        }
    }

    /* This is mostly used for dropdowns in the preferences menu.
     * The function will return the index of a value inside a given array.
     */
    private int get_string_array_index (string[] array, string value) {
        for (int i = 0; i < array.length; i++) {
            if (array[i] == value) {
                return i;
            }
        }
        return -1;
    }

    private void initialize_gsettings () {
        this.settings = new GLib.Settings ("io.github.v81d.Wattage");

        // Automation
        this.auto_refresh = this.settings.get_boolean ("auto-refresh");
        this.auto_refresh_cooldown = (int) this.settings.get_int ("auto-refresh-cooldown");

        // Measurements
        this.energy_unit = this.settings.get_string ("energy-unit");
        this.power_unit = this.settings.get_string ("power-unit");
        this.voltage_unit = this.settings.get_string ("voltage-unit");
    }

    private void initialize_preferences_dialog () {
        this.preferences_dialog_builder = new Gtk.Builder ();
        try {
            this.preferences_dialog_builder.add_from_resource ("/io/github/v81d/Wattage/preferences-dialog.ui");
        } catch (Error e) {
            stderr.printf ("Could not open preferences dialog: %s\n", e.message);
        }

        // Auto-refresh switch
        Adw.SwitchRow auto_refresh_switch = this.preferences_dialog_builder.get_object ("auto_refresh_switch") as Adw.SwitchRow;
        auto_refresh_switch.set_active (this.auto_refresh);

        if (this.auto_refresh) {
            this.start_auto_refresh ();
        }

        auto_refresh_switch.notify["active"].connect (() => {
            bool is_active = auto_refresh_switch.get_active ();
            this.settings.set_boolean ("auto-refresh", is_active);
            this.auto_refresh = is_active;

            if (is_active) {
                this.start_auto_refresh ();
            } else {
                this.stop_auto_refresh ();
            }

            load_device_list ();
        });

        // Auto-refresh delay
        Adw.SpinRow auto_refresh_cooldown_row = this.preferences_dialog_builder.get_object ("auto_refresh_cooldown_row") as Adw.SpinRow;
        auto_refresh_cooldown_row.set_value (this.auto_refresh_cooldown);

        auto_refresh_cooldown_row.notify["value"].connect (() => {
            int cooldown = (int) auto_refresh_cooldown_row.get_value ();
            this.settings.set_int ("auto-refresh-cooldown", cooldown);
            this.auto_refresh_cooldown = cooldown;

            // Restart auto-refresh loop
            if (this.auto_refresh) {
                this.stop_auto_refresh ();
                this.start_auto_refresh ();
            }

            load_device_list ();
        });

        // Energy unit
        string[] energy_units = { "μWh", "mWh", "Wh", "kWh", "J" };
        Adw.ComboRow energy_unit_row = this.preferences_dialog_builder.get_object ("energy_unit") as Adw.ComboRow;
        energy_unit_row.set_selected (get_string_array_index (energy_units, this.energy_unit));
        energy_unit_row.notify["selected"].connect (() => {
            string selected_unit = energy_units[energy_unit_row.get_selected ()];
            this.settings.set_string ("energy-unit", selected_unit);
            this.energy_unit = selected_unit;
            load_device_list ();
        });

        // Power unit
        string[] power_units = { "μW", "mW", "W", "kW", "J" };
        Adw.ComboRow power_unit_row = this.preferences_dialog_builder.get_object ("power_unit") as Adw.ComboRow;
        power_unit_row.set_selected (get_string_array_index (power_units, this.power_unit));
        power_unit_row.notify["selected"].connect (() => {
            string selected_unit = power_units[power_unit_row.get_selected ()];
            this.settings.set_string ("power-unit", selected_unit);
            this.power_unit = selected_unit;
            load_device_list ();
        });

        // Voltage unit
        string[] voltage_units = { "μV", "mV", "V", "kV" };
        Adw.ComboRow voltage_unit_row = this.preferences_dialog_builder.get_object ("voltage_unit") as Adw.ComboRow;
        voltage_unit_row.set_selected (get_string_array_index (voltage_units, this.voltage_unit));
        voltage_unit_row.notify["selected"].connect (() => {
            string selected_unit = voltage_units[voltage_unit_row.get_selected ()];
            this.settings.set_string ("voltage-unit", selected_unit);
            this.voltage_unit = selected_unit;
            load_device_list ();
        });
    }

    private void on_preferences_action () {
        Adw.PreferencesDialog preferences_dialog = this.preferences_dialog_builder.get_object ("preferences_dialog") as Adw.PreferencesDialog;
        preferences_dialog.present (this);
    }

    private void load_device_info (DeviceObject device) {
        this.content_spinner.set_visible (true);

        new Thread<void> ("load-device-info", () => {
            Gee.ArrayList<DeviceInfoSectionData> sections = new Gee.ArrayList<DeviceInfoSectionData> ();

            DeviceInfoSectionData general_info = new DeviceInfoSectionData (_("General Information"));
            general_info.set (_("Native Path"), device.native_path);
            general_info.set (_("Object Path"), device.object_path);
            general_info.set (_("Device Type"), device.device_type);
            sections.add (general_info);

            DeviceInfoSectionData model_details = new DeviceInfoSectionData (_("Model Details"));
            model_details.set (_("Vendor"), device.vendor);
            model_details.set (_("Serial Number"), device.serial);
            model_details.set (_("Model Name"), device.model);
            model_details.set (_("Technology"), device.technology);
            sections.add (model_details);

            DeviceInfoSectionData health_stats = new DeviceInfoSectionData (_("Health Evaluations"));

            if (device.capacity != null) {
                health_stats.set (_("State of Health"), "%.03f%%".printf (device.capacity));
            }

            string? health_alert = device.create_health_alert ();
            if (health_alert != null) {
                health_stats.set (_("Device Condition"), health_alert);
            }

            sections.add (health_stats);

            DeviceInfoSectionData charging_status = new DeviceInfoSectionData (_("Charging Status"));

            if (device.charge_start_threshold != null) {
                charging_status.set (_("Charge Start Threshold"), "%.03f%%".printf (device.charge_start_threshold));
            }

            if (device.charge_end_threshold != null) {
                charging_status.set (_("Charge End Threshold"), "%.03f%%".printf (device.charge_end_threshold));
            }

            if (device.charge_cycles != null) {
                charging_status.set (_("Cycle Count"), device.charge_cycles.to_string ());
            }

            double? current_charge = NumericToolkit.calculate_percentage (device.energy, device.energy_full);
            if (current_charge != null) {
                charging_status.set (_("Current Charge Percentage"), "%.03f%%".printf (current_charge));
            }

            charging_status.set (_("State"), device.state);
            sections.add (charging_status);

            DeviceInfoSectionData time_calculations = new DeviceInfoSectionData (_("Time Calculations"));

            string? time_to_empty = NumericToolkit.seconds_to_hms (device.time_to_empty);
            if (time_to_empty != null) {
                time_calculations.set (_("Time to Empty"), time_to_empty);
            }

            string? time_to_full = NumericToolkit.seconds_to_hms (device.time_to_full);
            if (time_to_full != null) {
                time_calculations.set (_("Time to Full"), time_to_full);
            }

            if (
                device.energy_full != null &&
                device.energy_rate != null &&
                device.energy_rate > 0 &&
                device.state == "Discharging"
            ) {
                string? projected_battery_life = NumericToolkit.seconds_to_hms ((int64) (device.energy_full / device.energy_rate * 3600));
                if (projected_battery_life != null) {
                    time_calculations.set (_("Projected Battery Life"), projected_battery_life);
                }
            }

            sections.add (time_calculations);

            DeviceInfoSectionData sensor_readings = new DeviceInfoSectionData (_("Sensor Readings"));

            if (device.temperature != null) {
                sensor_readings.set (_("Temperature"), "%.03f°C".printf (device.temperature));
            }

            sections.add (sensor_readings);

            DeviceInfoSectionData energy_metrics = new DeviceInfoSectionData (_("Energy Metrics"));

            if (device.energy_full_design != null) {
                double? converted = NumericToolkit.si_convert (device.energy_full_design, this.energy_unit);
                if (converted != null) {
                    energy_metrics.set (_("Maximum Rated Capacity"), "%.03f %s".printf (converted, this.energy_unit));
                }
            }

            if (device.energy_full != null) {
                double? converted = NumericToolkit.si_convert (device.energy_full, this.energy_unit);
                if (converted != null) {
                    energy_metrics.set (_("Maximum Capacity"), "%.03f %s".printf (converted, this.energy_unit));
                }
            }

            if (device.energy != null) {
                double? converted = NumericToolkit.si_convert (device.energy, this.energy_unit);
                if (converted != null) {
                    energy_metrics.set (_("Remaining Energy"), "%.03f %s".printf (converted, this.energy_unit));
                }
            }

            if (device.energy_rate != null) {
                double? converted = NumericToolkit.si_convert (device.energy_rate, this.power_unit);
                if (converted != null) {
                    energy_metrics.set (_("Energy Transfer Rate"), "%.03f %s".printf (converted, this.power_unit));
                }
            }

            sections.add (energy_metrics);

            DeviceInfoSectionData voltage_stats = new DeviceInfoSectionData (_("Voltage Statistics"));

            if (device.voltage_min_design != null) {
                double? converted = NumericToolkit.si_convert (device.voltage_min_design, this.voltage_unit);
                if (converted != null) {
                    voltage_stats.set (_("Minimum Rated Voltage"), "%.03f %s".printf (converted, this.voltage_unit));
                }
            }

            if (device.voltage != null) {
                double? converted = NumericToolkit.si_convert (device.voltage, this.voltage_unit);
                if (converted != null) {
                    voltage_stats.set (_("Current Voltage"), "%.03f %s".printf (converted, this.voltage_unit));
                }
            }

            sections.add (voltage_stats);

            Idle.add (() => {
                // Titles of existing sections
                Gee.ArrayList<string> existing_titles = new Gee.ArrayList<string> ();
                foreach (DeviceInfoSection section in this.device_info_sections) {
                    existing_titles.add (section.title);
                }

                // Titles of new sections
                Gee.ArrayList<string> new_titles = new Gee.ArrayList<string> ();
                foreach (DeviceInfoSectionData section in sections) {
                    if (section.properties.size > 0) {
                        new_titles.add (section.title);
                    }
                }

                // We need to check if both title arrays are exactly the same
                bool titles_match = true;
                if (existing_titles.size != new_titles.size) {
                    titles_match = false;
                } else {
                    foreach (string title in new_titles) {
                        if (!existing_titles.contains (title)) {
                            titles_match = false;
                            break;
                        }
                    }
                }

                /* We should reconstruct the entire content view if the two arrays do not match.
                 *  - If we were to simply append the missing sections, they would be added directly to the end of the content, which is not always desired.
                 *  - Rebuilding the view would be the simplest way to resolve this.
                 * If the two arrays do match, however, we should just update existing sections in place.
                 */
                if (!titles_match) {
                    foreach (DeviceInfoSection s in this.device_info_sections) {
                        this.device_info_box.remove (s);
                    }
                    this.device_info_sections.clear ();

                    foreach (DeviceInfoSectionData section in sections) {
                        if (section.properties.size == 0) {
                            continue;
                        }

                        DeviceInfoSection s = new DeviceInfoSection (section.title, section.properties);
                        this.device_info_box.append (s);
                        this.device_info_sections.add (s);
                    }
                } else {
                    foreach (DeviceInfoSectionData section in sections) {
                        if (section.properties.size == 0) {
                            continue;
                        }

                        // Match existing sections by title
                        DeviceInfoSection? existing_section = null;
                        foreach (DeviceInfoSection s in this.device_info_sections) {
                            if (s.title == section.title) {
                                existing_section = s;
                                break;
                            }
                        }

                        if (existing_section != null) {
                            existing_section.update (section.properties);
                        }
                    }
                }

                this.content_spinner.set_visible (false);
                this.device_info_empty_status.set_visible (this.device_info_sections.size == 0);

                return false;
            });
        });
    }

    private void load_device_list () {
        this.sidebar_spinner.set_visible (true);

        Gtk.ListBoxRow? row;
        while ((row = this.device_list.get_row_at_index (0)) != null) {
            this.device_list.remove (row);
        }

        new Thread<void> ("load-device-list", () => {
            List<DeviceObject> devices;

            try {
                devices = this.device_prober.get_devices ();
                stdout.printf ("Power devices loaded.\n");
                device_list_empty_status.set_visible (false);
                this.device_info_empty_status.set_visible (false);
            } catch (Error e) {
                stderr.printf ("Failed to load power devices: %s\n", (string) e);
                devices = new List<DeviceObject> ();
            }

            Idle.add (() => {
                foreach (DeviceObject device in devices) {
                    this.append_device (device);
                }

                if (this.device_list.get_row_at_index (this.selected_device_index) != null) {
                    this.device_list.select_row (this.device_list.get_row_at_index (this.selected_device_index));
                } else if (this.device_list.get_row_at_index (0) != null) {
                    this.device_list.select_row (this.device_list.get_row_at_index (0));
                    stdout.printf ("The device at index %s cannot be found. Device at index 0 will be selected.\n", this.selected_device_index.to_string ());
                } else {
                    stderr.printf ("No power devices have been detected by UPower.\n");
                    this.device_list_empty_status.set_visible (true);
                    this.device_info_empty_status.set_visible (true);
                }

                this.sidebar_spinner.set_visible (false);

                return false;
            });
        });
    }

    private void append_device (DeviceObject device) {
        DeviceRow row = new DeviceRow (device);
        this.device_list.append (row);
    }

    [GtkCallback]
    public void on_toggle_sidebar_toggled (Gtk.ToggleButton button) {
        bool is_active = button.get_active ();
        this.split_view.set_show_sidebar (is_active);
    }

    // Keyboard shortcut select next device action
    private void on_select_next_device_action () {
        if (this.device_list.get_selected_row () != this.device_list.get_last_child ()) {
            this.device_list.select_row (this.device_list.get_row_at_index (this.selected_device_index + 1));
        }
    }

    // Keyboard shortcut select previous device action
    private void on_select_previous_device_action () {
        if (this.device_list.get_selected_row () != this.device_list.get_first_child ()) {
            this.device_list.select_row (this.device_list.get_row_at_index (this.selected_device_index - 1));
        }
    }

    // Keyboard shortcut refresh action
    private void on_refresh_action () {
        load_device_list ();
    }

    // Refresh button clicked action
    [GtkCallback]
    public void on_refresh_clicked (Gtk.Button _) {
        load_device_list ();
    }
}
