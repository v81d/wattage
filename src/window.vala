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

/* Define the class `DeviceRow`, which inherits from `Gtk.ListBoxRow`.
 * Use as a constructor for a single row in the device list sidebar.
 */
public class DeviceRow : Gtk.ListBoxRow {
    public DeviceRow (string name, string description, string icon_name) {
        Adw.ActionRow row = new Adw.ActionRow ();
        row.set_title (name);
        row.set_subtitle (description);

        // Due to the deprecation of `row.icon_name` and `row.set_icon_name ()`, the icon should be prepended as a widget
        Gtk.Image icon = new Gtk.Image.from_icon_name (icon_name);
        icon.set_pixel_size (24);
        row.add_prefix (icon);

        this.set_child (row);
    }
}

/* This class inherits from `Gtk.Box`.
 * Use as a constructor for a single section in the device information view.
 */
public class DeviceInfoSection : Gtk.Box {
    private string _title;
    private Gtk.ListBox _list;

    public DeviceInfoSection (string title, Gee.ArrayList<DeviceInfoSectionData.DeviceProperty> properties) {
        this._title = title;
        this.set_orientation (Gtk.Orientation.VERTICAL);
        this.set_spacing (12);

        Gtk.Label label = new Gtk.Label (title);
        label.set_halign (Gtk.Align.START);
        label.add_css_class ("title-2");
        this.append (label);

        this._list = new Gtk.ListBox ();
        this._list.set_selection_mode (Gtk.SelectionMode.NONE);
        this._list.set_hexpand (true);
        this._list.add_css_class ("boxed-list");
        this.append (this._list);

        this.update (properties);
    }

    public string get_title () {
        return this._title;
    }

    public void update (Gee.ArrayList<DeviceInfoSectionData.DeviceProperty> properties) {
        Gtk.ListBoxRow? row;
        while ((row = this._list.get_row_at_index (0)) != null) {
            this._list.remove (row);
        }

        foreach (DeviceInfoSectionData.DeviceProperty property in properties) {
            Adw.ActionRow action_row = new Adw.ActionRow ();
            action_row.set_title (property.name);
            action_row.set_subtitle (property.value);
            action_row.set_subtitle_selectable (true);
            action_row.set_css_classes ({ "property", "monospace" });
            this._list.append (action_row);
        }
    }
}

public class DeviceInfoSectionData {
    public class DeviceProperty {
        public string name;
        public string value;

        public DeviceProperty (string name, string value) {
            this.name = name;
            this.value = value;
        }
    }

    public string title;
    public Gee.ArrayList<DeviceProperty> properties;

    public DeviceInfoSectionData (string title) {
        this.title = title;
        this.properties = new Gee.ArrayList<DeviceProperty> ();
    }

    public void set (string name, string value) {
        if (!value.down ().contains ("unknown") && value.length > 0) {
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

    private Wattage.BatteryManager battery_manager;
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

        this.battery_manager = new Wattage.BatteryManager ();
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
                            this.load_device_info (this.battery_manager.fetch_device (action_row.get_title ()));
                            return false;
                        });
                    }
                }
            }
        });

        this.settings = new GLib.Settings ("io.github.v81d.Wattage"); // gsettings

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
            stderr.printf ("[preferences_dialog_builder.add_from_resource ()] %s\n", e.message);
        }

        // Auto-refresh switch
        Adw.SwitchRow auto_refresh_switch = this.preferences_dialog_builder.get_object ("auto_refresh_switch") as Adw.SwitchRow;
        auto_refresh_switch.set_active (this.auto_refresh);

        if (this.auto_refresh) {
            this.start_auto_refresh ();
        } else {
            this.stop_auto_refresh ();
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

    private void load_device_info (Wattage.Device device) {
        this.content_spinner.set_visible (true);

        new Thread<void> ("load-device-info", () => {
            Gee.ArrayList<DeviceInfoSectionData> sections = new Gee.ArrayList<DeviceInfoSectionData> ();

            DeviceInfoSectionData general_info = new DeviceInfoSectionData (_("General Information"));
            general_info.set (_("Device Name"), device.name);
            general_info.set (_("Sysfs Path"), device.path);
            general_info.set (_("Device Type"), device.map_property_translation (device.type));
            sections.add (general_info);

            DeviceInfoSectionData manufacturing_details = new DeviceInfoSectionData (_("Manufacturing Details"));
            manufacturing_details.set (_("Manufacturer"), device.manufacturer);
            manufacturing_details.set (_("Serial Number"), device.serial_number);
            sections.add (manufacturing_details);

            DeviceInfoSectionData model_info = new DeviceInfoSectionData (_("Model Information"));
            model_info.set (_("Model Name"), device.model_name);
            model_info.set (_("Technology"), device.technology);
            sections.add (model_info);

            DeviceInfoSectionData health_stats = new DeviceInfoSectionData (_("Health Evaluations"));
            string health_percentage = device.calculate_percentage (double.parse (device.energy_full), double.parse (device.energy_full_design));
            health_stats.set (_("State of Health"), health_percentage + "%");
            health_stats.set (_("Device Condition"), device.create_alert (double.parse (health_percentage)));
            sections.add (health_stats);

            DeviceInfoSectionData charging_status = new DeviceInfoSectionData (_("Charging Status"));
            charging_status.set (_("Charge Limit Percentage"), device.charge_control_end_threshold + "%");
            charging_status.set (_("Cycle Count"), device.cycle_count);
            charging_status.set (_("Current Charge Percentage"), device.calculate_percentage (double.parse (device.energy_now), double.parse (device.energy_full)) + "%");
            charging_status.set (_("Status"), device.map_property_translation (device.status));
            sections.add (charging_status);

            DeviceInfoSectionData time_calculations = new DeviceInfoSectionData (_("Time Calculations"));
            time_calculations.set (_("Time to Empty"), device.calculate_time (device.energy_now));
            time_calculations.set (_("Projected Runtime with Current Usage"), device.calculate_time (device.energy_full));
            sections.add (time_calculations);

            DeviceInfoSectionData energy_metrics = new DeviceInfoSectionData (_("Energy Metrics"));
            energy_metrics.set (_("Maximum Rated Capacity"), device.convert_to_unit (device.energy_full_design, this.energy_unit));
            energy_metrics.set (_("Maximum Capacity"), device.convert_to_unit (device.energy_full, this.energy_unit));
            energy_metrics.set (_("Remaining Energy"), device.convert_to_unit (device.energy_now, this.energy_unit));
            energy_metrics.set (_("Energy Transfer Rate"), device.convert_to_unit (device.power_now, this.power_unit));
            sections.add (energy_metrics);

            DeviceInfoSectionData voltage_stats = new DeviceInfoSectionData (_("Voltage Statistics"));
            voltage_stats.set (_("Minimum Rated Voltage"), device.convert_to_unit (device.voltage_min_design, this.voltage_unit));
            voltage_stats.set (_("Current Voltage"), device.convert_to_unit (device.voltage_now, this.voltage_unit));
            sections.add (voltage_stats);

            Idle.add (() => {
                // Titles of existing sections
                Gee.ArrayList<string> existing_titles = new Gee.ArrayList<string> ();
                foreach (DeviceInfoSection s in this.device_info_sections) {
                    existing_titles.add (s.get_title ());
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

                /* Essentially, we should reconstruct the entire content view if the two arrays do not match.
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
                            if (s.get_title () == section.title) {
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
            List<Wattage.Device> devices;

            try {
                devices = this.battery_manager.get_devices ();
                stdout.printf ("Power devices loaded.\n");
                device_list_empty_status.set_visible (false);
                this.device_info_empty_status.set_visible (false);
            } catch (Error e) {
                stderr.printf ("Failed to load power devices: %s\n", (string) e);
                devices = new List<Wattage.Device> ();
                this.device_list_empty_status.set_visible (true);
                this.device_info_empty_status.set_visible (true);
            }

            Idle.add (() => {
                foreach (Wattage.Device device in devices) {
                    this.append_device (device);
                }

                if (this.device_list.get_row_at_index (this.selected_device_index) != null) {
                    this.device_list.select_row (this.device_list.get_row_at_index (this.selected_device_index));
                } else if (this.device_list.get_row_at_index (0) != null) {
                    this.device_list.select_row (this.device_list.get_row_at_index (0));
                    stdout.printf ("The device at index %s cannot be found. Device at index 0 will be selected.\n", this.selected_device_index.to_string ());
                } else {
                    stderr.printf ("No power devices found under the sysfs path.\n");
                }

                this.sidebar_spinner.set_visible (false);

                return false;
            });
        });
    }

    private void append_device (Wattage.Device device) {
        string description = _("Path: %s\nType: %s").printf (device.path, device.type);
        DeviceRow row = new DeviceRow (device.name, description, device.icon_name);
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

