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
        row.title = name;
        row.subtitle = description;

        // Due to the deprecation of `row.icon_name` and `row.set_icon_name ()`, the icon should be prepended as a widget
        Gtk.Image icon = new Gtk.Image.from_icon_name (icon_name);
        row.add_prefix (icon);

        this.set_child (row);
    }
}

[GtkTemplate (ui = "/com/v81d/Ampere/window.ui")]
public class Ampere.Window : Adw.ApplicationWindow {
    // For easier access, bind template children to variables
    [GtkChild] unowned Adw.Spinner loading_spinner;
    [GtkChild] unowned Gtk.ListBox device_list;

    private Ampere.BatteryManager battery_manager;

    public Window (Gtk.Application app) {
        Object (application: app);

        battery_manager = new Ampere.BatteryManager ();
        load_devices ();
    }

    private void load_devices () {
        loading_spinner.set_visible (true);

        Gtk.ListBoxRow? row;
        while ((row = device_list.get_row_at_index (0)) != null) {
            device_list.remove (row);
        }

        // To prevent blocking, load on a separate thread
        Thread<void> thread = new Thread<void> (
                                                "load-devices",
                                                () => {
            List<Ampere.Device> devices;

            try {
                devices = battery_manager.get_devices ();
                stdout.printf ("Devices loaded.\n");
            } catch (Error e) {
                stderr.printf ("Failed to load devices: %s\n", (string) e);
                devices = new List<Ampere.Device> ();
            }

            Idle.add (() => {
                foreach (Ampere.Device device in devices) {
                    append_device (device);
                }
                loading_spinner.set_visible (false);
                return false;
            });
        });
    }

    private void append_device (Ampere.Device device) {
        string description = "Type: %s\nManufacturer: %s".printf (device.type, device.manufacturer);
        DeviceRow row = new DeviceRow (device.name, description, device.icon_name);
        device_list.append (row);
        row.show ();
    }

    // Callback for clicking the refresh button
    [GtkCallback]
    public void on_refresh_clicked (Gtk.Button button) {
        load_devices ();
        // TODO: refresh device info in the content view
    }
}
