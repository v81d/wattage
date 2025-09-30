/* battery_manager.vala
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

namespace Ampere {
    // This class is used to represent a single device object
    public class Device {
        public string name;
        public string path;
        public string type;
        public string manufacturer;
        public string icon_name;

        public Device (string name = "", string path = "", string type = "", string manufacturer = "", string icon_name = "") {
            this.name = name;
            this.path = path;
            this.type = type;
            this.manufacturer = manufacturer;
            this.icon_name = icon_name;
        }
    }

    // This is the publicly accessible class used to probe, enumerate, and inspect battery devices
    public class BatteryManager : Object {
        private const string POWER_SUPPLY_PATH = "/sys/class/power_supply"; // directory for device folders

        public BatteryManager () {}

        private string read_file (string filepath, string fallback = "Unknown") {
            try {
                string content;
                if (FileUtils.get_contents (filepath, out content)) {
                    return content.strip ();
                }
            } catch (Error e) {}
            return fallback;
        }

        // This method is used to methodically determine the symbolic icon name based on information about a given device
        private string get_device_icon_name (string device_path) {
            string device_name = Path.get_basename (device_path);
            string sysfs_path = Path.build_filename (POWER_SUPPLY_PATH, device_name);

            // Store the properties of the device
            string present = read_file (Path.build_filename (sysfs_path, "present"));
            string capacity_string = read_file (Path.build_filename (sysfs_path, "capacity"));
            string status = read_file (Path.build_filename (sysfs_path, "status"));

            // If `present` is not 1 (true), then the device is missing
            if (present != "1") {
                return "battery-missing-symbolic";
            }

            int capacity = capacity_string != "" ? int.parse (capacity_string) : -1;
            string state = status.down ();

            if (state == "full" || state == "not charging") {
                return "battery-full-charged-symbolic";
            }

            if (capacity == 0 && (state == "discharging" || state == "unknown")) {
                return "battery-empty-symbolic";
            }

            string level = "";
            if (capacity <= 10) {
                level = "caution";
            } else if (capacity <= 30) {
                level = "low";
            } else if (capacity <= 90) {
                level = "good";
            } else {
                level = "full";
            }

            string suffix = "";
            if (state == "charging") {
                suffix = "-charging";
            }

            return "battery-" + level + suffix + "-symbolic";
        }

        public List<Device> get_devices () throws GLib.Error {
            List<Device> result = new List<Device> ();

            File path = File.new_for_path (POWER_SUPPLY_PATH);
            var enumerator = path.enumerate_children ("*", FileQueryInfoFlags.NONE, null);

            FileInfo info;
            while ((info = enumerator.next_file (null)) != null) {
                /* This loop should only accept folders that represent a power device such as a battery.
                 * If the device is not a folder, skip it.
                 */
                if (info.get_file_type () != FileType.DIRECTORY) {
                    continue;
                }

                string device_name = info.get_name ();
                string device_path = Path.build_filename (POWER_SUPPLY_PATH, device_name);
                string device_type = read_file (Path.build_filename (device_path, "type"));
                string device_manufacturer = read_file (Path.build_filename (device_path, "manufacturer"));
                string device_icon_name = get_device_icon_name (device_path);

                result.append (new Device (device_name, device_path, device_type, device_manufacturer, device_icon_name));
            }

            /* Usually, users will most likely be looking for information regarding their battery.
             * Other devices should listed after batteries.
             * The sorting comparison below moves batteries to the beginning and sorts miscellaneous devices after.
             */
            result.sort ((a, b) => {
                if (a.type == "Battery" && b.type != "Battery") {
                    return -1; // a before b
                } else if (a.type != "Battery" && b.type == "Battery") {
                    return 1; // b before a
                } else {
                    return strcmp (a.name, b.name); // alphabetical order
                }
            });

            return result;
        }
    }
}
