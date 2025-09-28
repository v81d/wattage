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

/* Define the class `DeviceRow`, which inherits from `Gtk.ListBoxRow`.
 * Use as a constructor for a single row in the device list sidebar.
 */
public class DeviceRow : Gtk.ListBoxRow {
    public DeviceRow (string title, string subtitle, string icon_name) {
        Adw.ActionRow row = new Adw.ActionRow ();
        row.title = title;
        row.subtitle = subtitle;

        // Due to the deprecation of `row.icon_name` and `row.set_icon_name ()`, the icon should be prepended as a widget
        Gtk.Image icon = new Gtk.Image.from_icon_name (icon_name);
        row.add_prefix (icon);

        this.set_child (row);
    }
}

[GtkTemplate (ui = "/com/v81d/Ampere/window.ui")]
public class Ampere.Window : Adw.ApplicationWindow {
    // For easier access, bind template children to variables
    [GtkChild] unowned Gtk.ListBox device_list;

    public Window (Gtk.Application app) {
        Object (application: app);
    }

    private void append_device (string title, string subtitle, string icon_name) {
        DeviceRow row = new DeviceRow (title, subtitle, icon_name);
        device_list.append (row);
        row.show ();
    }
}
