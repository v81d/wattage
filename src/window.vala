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
    public DeviceInfoSection (string title, Gee.ArrayList<DeviceInfoSectionData.DeviceProperty> properties) {
        if (properties.is_empty) {
            return;
        }

        // Properties for the parent `Gtk.Box` object
        this.set_orientation (Gtk.Orientation.VERTICAL);
        this.set_spacing (12);

        // Title of the section
        Gtk.Label label = new Gtk.Label (title);
        label.set_halign (Gtk.Align.START);
        label.add_css_class ("title-2");

        this.append (label);

        // `Gtk.ListBox` displaying all properties of the device
        Gtk.ListBox section = new Gtk.ListBox ();
        section.set_selection_mode (Gtk.SelectionMode.NONE);
        section.set_hexpand (true);
        section.add_css_class ("boxed-list");

        // Create a row for each property
        foreach (DeviceInfoSectionData.DeviceProperty property in properties) {
            Adw.ActionRow row = new Adw.ActionRow ();
            row.set_title (property.name);
            row.set_subtitle (property.value);
            row.set_subtitle_selectable (true);
            row.set_css_classes ({ "property", "monospace" });

            section.append (row);
        }

        this.append (section);
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

[GtkTemplate (ui = "/com/v81d/Ampere/window.ui")]
public class Ampere.Window : Adw.ApplicationWindow {
    // Bind template children to variables
    [GtkChild] unowned Adw.Spinner sidebar_spinner;
    [GtkChild] unowned Adw.Spinner content_spinner;
    [GtkChild] unowned Adw.OverlaySplitView split_view;
    [GtkChild] unowned Gtk.ListBox device_list;
    [GtkChild] unowned Gtk.Box device_info_box;

    private Ampere.BatteryManager battery_manager;
    private int selected_device_index = 0;

    public Window (Gtk.Application app) {
        Object (application: app);

        this.battery_manager = new Ampere.BatteryManager ();
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
                            this.load_device_info (this.battery_manager.fetch_device (action_row.get_title ()));
                            return false;
                        });
                    }
                }
            }
        });
    }

    construct {
        SimpleAction refresh_action = new SimpleAction ("refresh", null);
        refresh_action.activate.connect (this.on_refresh_action);
        this.add_action (refresh_action);
    }

    private void load_device_info (Ampere.Device device) {
        this.content_spinner.set_visible (true);

        // Clear all sections before adding them back
        Gtk.Widget? widget;
        while ((widget = this.device_info_box.get_first_child ()) != null) {
            this.device_info_box.remove (widget);
        }

        // To prevent blocking, load on a separate thread
        new Thread<void> ("load-device-info", () => {
            Gee.ArrayList<DeviceInfoSectionData> sections = new Gee.ArrayList<DeviceInfoSectionData> ();

            DeviceInfoSectionData basic_info = new DeviceInfoSectionData ("Basic Information");
            basic_info.set ("Device Name", device.name);
            basic_info.set ("Sysfs Path", device.path);
            basic_info.set ("Device Type", device.type);
            basic_info.set ("Status", device.status);
            sections.add (basic_info);

            DeviceInfoSectionData health_stats = new DeviceInfoSectionData ("Health Evaluations");
            string health_percentage = device.calculate_health_percentage ();
            health_stats.set ("State of Health", health_percentage + "%");
            health_stats.set ("Device Condition", device.create_alert (double.parse (health_percentage)));
            sections.add (health_stats);

            DeviceInfoSectionData manufacturing_details = new DeviceInfoSectionData ("Manufacturing Details");
            manufacturing_details.set ("Manufacturer", device.manufacturer);
            manufacturing_details.set ("Serial Number", device.serial_number);
            sections.add (manufacturing_details);

            DeviceInfoSectionData model_info = new DeviceInfoSectionData ("Model Information");
            model_info.set ("Model Name", device.model_name);
            model_info.set ("Technology", device.technology);
            sections.add (model_info);

            DeviceInfoSectionData charging_status = new DeviceInfoSectionData ("Charging Status");
            charging_status.set ("Charge Limit Percentage", device.charge_control_end_threshold + "%");
            charging_status.set ("Cycle Count", device.cycle_count);
            sections.add (charging_status);

            DeviceInfoSectionData energy_metrics = new DeviceInfoSectionData ("Energy Metrics");
            energy_metrics.set ("Maximum Rated Capacity", device.energy_full_design + " Wh");
            energy_metrics.set ("Maximum Capacity", device.energy_full + " Wh");
            energy_metrics.set ("Remaining Power", device.energy_now + " Wh");
            energy_metrics.set ("Energy Rate", device.power_now + " W");
            sections.add (energy_metrics);

            DeviceInfoSectionData voltage_stats = new DeviceInfoSectionData ("Voltage Statistics");
            voltage_stats.set ("Minimum Rated Voltage", device.voltage_min_design + " V");
            voltage_stats.set ("Current Voltage", device.voltage_now + " V");
            sections.add (voltage_stats);

            Idle.add (() => {
                foreach (DeviceInfoSectionData section in sections) {
                    DeviceInfoSection device_info_section = new DeviceInfoSection (section.title, section.properties);
                    if (device_info_section.get_first_child () != null) {
                        this.device_info_box.append (device_info_section);
                    }
                }

                this.content_spinner.set_visible (false);

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
            List<Ampere.Device> devices;

            try {
                devices = this.battery_manager.get_devices ();
                stdout.printf ("Power devices loaded.\n");
            } catch (Error e) {
                stderr.printf ("Failed to load power devices: %s\n", (string) e);
                devices = new List<Ampere.Device> ();
            }

            Idle.add (() => {
                foreach (Ampere.Device device in devices) {
                    this.append_device (device);
                }

                if (this.device_list.get_row_at_index (this.selected_device_index) != null) {
                    this.device_list.select_row (this.device_list.get_row_at_index (this.selected_device_index));
                } else if (this.device_list.get_row_at_index (0) != null) {
                    this.device_list.select_row (this.device_list.get_row_at_index (0));
                    this.selected_device_index = 0;
                    stdout.printf ("The device at index %s cannot be found. Device at index 0 will be selected.\n", this.selected_device_index.to_string ());
                } else {
                    stderr.printf ("No power devices found under the sysfs path.\n");
                }

                this.sidebar_spinner.set_visible (false);

                return false;
            });
        });
    }

    private void append_device (Ampere.Device device) {
        string description = "Path: %s\nType: %s".printf (device.path, device.type);
        DeviceRow row = new DeviceRow (device.name, description, device.icon_name);
        this.device_list.append (row);
    }

    [GtkCallback]
    public void on_toggle_sidebar_toggled (Gtk.ToggleButton button) {
        bool is_active = button.get_active ();
        this.split_view.set_show_sidebar (is_active);
    }

    private void on_refresh_action () {
        load_device_list ();
        // The device information will be refreshed automatically
    }

    [GtkCallback]
    public void on_refresh_clicked (Gtk.Button button) {
        load_device_list ();
    }
}
