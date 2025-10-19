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

namespace Wattage {
    // This class is used to represent basic information about a single device
    public class Device {
        public string name = "Unknown";
        public string path = "Unknown";
        public string type = "Unknown";
        public string status = "Unknown";
        public string manufacturer = "Unknown";
        public string serial_number = "Unknown";
        public string model_name = "Unknown";
        public string technology = "Unknown";
        public string state_of_health = "Unknown";
        public string charge_control_end_threshold = "Unknown"; // charge limit
        public string cycle_count = "Unknown";
        public string energy_full_design = "Unknown"; // original maximum capacity
        public string energy_full = "Unknown"; // maximum capacity
        public string energy_now = "Unknown";
        public string power_now = "Unknown"; // energy rate
        public string voltage_min_design = "Unknown"; // original minimum voltage
        public string voltage_now = "Unknown";
        public string icon_name = "Unknown";

        public Device () {}

        public string convert_to_unit (string value, string unit) {
            // Assumes starting unit of value is micro(-units)
            double val = double.parse (value);

            if (unit.has_prefix ("m")) {
                // mWh, mW, mV
                val /= 1000;
            } else if (unit.has_prefix ("k")) {
                // kWh, kW, kV
                val /= 1000000000;
            } else if (unit == "J") {
                val *= 0.0036;
            } else if (!unit.has_prefix ("μ")) {
                // standard case (Wh, W, V)
                val /= 1000000;
            }

            return val == 0 ? "Unknown" : "%.3f %s".printf (val, unit);
        }

        public string calculate_percentage (double part, double total) {
            /* In some special cases, the total may be 0.
             * To avoid division by zero, we should instead return "Unknown" early.
             */
            if (total == 0) {
                return "Unknown";
            }

            double percentage = (part / total) * 100;
            return "%0.3f".printf (percentage);
        }

        public string hours_to_hms (double hours) {
            int total_seconds = (int) (hours * 3600);

            int result_hours = total_seconds / 3600;
            int result_seconds = total_seconds - result_hours * 3600;
            int result_minutes = result_seconds / 60;
            result_seconds -= result_minutes * 60;

            return "%02d:%02d:%02d".printf (result_hours, result_minutes, result_seconds);
        }

        public string calculate_time (string total_energy) {
            double total = double.parse (total_energy);
            double rate = double.parse (this.power_now);

            if (rate == 0 || this.status.down () == "charging") {
                return "Unknown";
            }

            return this.hours_to_hms (total / rate);
        }

        public string create_alert (double health_percentage) {
            if (health_percentage >= 90) {
                return _("The device performs close to its original capacity. It is suitable for daily use with minimal wear.");
            } else if (health_percentage >= 80) {
                return _("The device bears slight capacity loss but is still in good condition for most tasks.");
            } else if (health_percentage >= 70) {
                return _("The device shows a considerable degradation in capacity. Usage time is noticeably shorter than at its optimal state.");
            } else if (health_percentage >= 50) {
                return _("The device has a significant drop in capacity. Expect arbitrary shutdowns and shortened runtime during extended use.");
            } else if (health_percentage > 0) {
                return _("The device has experienced substantial deterioration. Consider replacing the device to avoid further damage.");
            } else {
                return "Unknown";
            }
        }

        public string map_property_translation (string property_value) {
            // The below switch statement should not match any "Unknown" values, as those should not be translated nor displayed to the user
            switch (property_value.down ()) {
            // `device.type`
            case "battery":
                return _("Battery");
            case "ups":
                return _("UPS");
            case "mains":
                return _("Mains");
            case "usb":
                return _("USB");
            case "wireless":
                return _("Wireless");

            // `device.status`
            case "charging":
                return _("Charging");
            case "discharging":
                return _("Discharging");
            case "not charging":
                return _("Not charging");
            case "full":
                return _("Full");

            // If none of the above match, just return the untranslated property value
            default:
                return property_value;
            }
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
            } catch (Error _) {}
            return fallback;
        }

        // This method is used to methodically determine the symbolic icon name based on information about a given device
        private string get_device_icon_name (string device_path) {
            // Store the properties of the device
            string present = this.read_file (Path.build_filename (device_path, "present"));
            string capacity_string = this.read_file (Path.build_filename (device_path, "capacity"));
            string status = this.read_file (Path.build_filename (device_path, "status"));

            // If `present` is not 1 (true), then the device is missing
            if (present != "1") {
                return "battery-missing-symbolic";
            }

            int capacity = capacity_string != "" ? int.parse (capacity_string) : -1;
            string state = status.down ();

            if (state == "full" || state == "not charging") {
                return "battery-full-charged-symbolic";
            }

            if (capacity == 0 && (state == "discharging" || state.down ().contains ("unknown"))) {
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
            FileEnumerator enumerator = path.enumerate_children ("*", FileQueryInfoFlags.NONE, null);

            FileInfo info;
            while ((info = enumerator.next_file (null)) != null) {
                /* This loop should only accept folders that represent a power device such as a battery.
                 * If the device is not a folder, skip it.
                 */
                if (info.get_file_type () != FileType.DIRECTORY) {
                    continue;
                }

                Device device = new Device ();
                device.name = info.get_name ();
                device.path = Path.build_filename (POWER_SUPPLY_PATH, device.name);
                device.type = this.read_file (Path.build_filename (device.path, "type"));
                device.icon_name = this.get_device_icon_name (device.path);
                result.append (device);
            }

            /* Usually, users will most likely be looking for information regarding their battery.
             * Other devices should listed after batteries.
             * The sorting comparison below moves batteries to the beginning and sorts miscellaneous devices after.
             */
            result.sort ((a, b) => {
                if (a.type.down () == "battery" && b.type.down () != "battery") {
                    return -1; // a before b
                } else if (a.type.down () != "battery" && b.type.down () == "battery") {
                    return 1; // b before a
                } else {
                    return strcmp (a.name, b.name); // alphabetical order
                }
            });

            return result;
        }

        public Device fetch_device (string device_name) {
            /* Fetch all properties, statistics, and information about the specified device.
             * Should create a `Device` object containing all necessary information.
             */
            Device device = new Device ();

            device.name = device_name;
            device.path = Path.build_filename (POWER_SUPPLY_PATH, device_name);
            device.type = this.read_file (Path.build_filename (device.path, "type"));

            device.manufacturer = this.read_file (Path.build_filename (device.path, "manufacturer"));

            // Mask serial number
            string serial_number = this.read_file (Path.build_filename (device.path, "serial_number"));
            string masked_serial_number;
            if (serial_number.length > 4 && !serial_number.down ().contains ("unknown")) {
                int mask_length = serial_number.length - 4;
                string mask = "";
                for (int i = 0; i < mask_length; i++) {
                    mask += "*";
                }
                masked_serial_number = mask + serial_number.slice (mask_length, serial_number.length);
            } else {
                masked_serial_number = serial_number;
            }

            device.serial_number = masked_serial_number;

            device.model_name = this.read_file (Path.build_filename (device.path, "model_name"));
            device.technology = this.read_file (Path.build_filename (device.path, "technology"));

            // These should be calculated before state of health
            device.energy_full_design = this.read_file (Path.build_filename (device.path, "energy_full_design"));
            device.energy_full = this.read_file (Path.build_filename (device.path, "energy_full"));

            string state_of_health = device.state_of_health = this.read_file (Path.build_filename (device.path, "state_of_health"));
            device.state_of_health = state_of_health.down () != "unknown" ? state_of_health : device.calculate_percentage (double.parse (device.energy_full), double.parse (device.energy_full_design));

            double charge_control_end_threshold = double.parse (this.read_file (Path.build_filename (device.path, "charge_control_end_threshold")));
            device.charge_control_end_threshold = charge_control_end_threshold == 0 ? "Unknown" : "%0.3f".printf (charge_control_end_threshold);
            device.cycle_count = this.read_file (Path.build_filename (device.path, "cycle_count"));
            device.status = this.read_file (Path.build_filename (device.path, "status"));

            // Energy metrics (including `energy_full_design` and `energy_full`)
            device.energy_now = this.read_file (Path.build_filename (device.path, "energy_now"));
            device.power_now = this.read_file (Path.build_filename (device.path, "power_now"));

            device.voltage_min_design = this.read_file (Path.build_filename (device.path, "voltage_min_design"));
            device.voltage_now = this.read_file (Path.build_filename (device.path, "voltage_now"));

            device.icon_name = this.get_device_icon_name (device.path);

            return device;
        }
    }
}
