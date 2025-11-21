/* device-manager.vala
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
using org.freedesktop;

namespace Wattage {
    // This class is used to represent basic information about a single device
    public class Device {
        public UPower.Device upower_proxy { get; set; }

        public string path { get; set; default = "unknown"; }

        public string name { get; set; default = "unknown"; }
        public string vendor { get; set; default = "unknown"; }
        public string model { get; set; default = "unknown"; }
        public string serial { get; set; default = "unknown"; }

        public string device_type { get; set; default = "unknown"; }
        public string technology { get; set; default = "unknown"; }

        public string state { get; set; default = "unknown"; }

        public string energy { get; set; default = "unknown"; }
        public string energy_full { get; set; default = "unknown"; }
        public string energy_full_design { get; set; default = "unknown"; }
        public string energy_rate { get; set; default = "unknown"; }
        public string voltage { get; set; default = "unknown"; }
        public string voltage_min_design { get; set; default = "unknown"; }

        public string charge_cycles { get; set; default = "unknown"; }
        public string charge_control_end_threshold { get; set; default = "unknown"; }

        public string capacity { get; set; default = "unknown"; }
        public string icon_name { get; set; default = "unknown"; }

        public Device () {}

        public string convert_to_unit (string value, string unit) {
            // Assumes starting unit of value is base unit
            double val = double.parse (value);

            if (unit.has_prefix ("μ")) {
                // μ-unit
                val *= 1000000;
            } else if (unit.has_prefix ("m")) {
                // m-unit
                val *= 1000;
            } else if (unit.has_prefix ("k")) {
                // k-unit
                val /= 1000;
            } else if (unit == "J") {
                // Joules
                val *= 3600;
            }

            return val == 0 ? "unknown" : "%.3f %s".printf (val, unit);
        }

        public string calculate_percentage (double part, double total) {
            /* In some special cases, the total may be 0.
             * To avoid division by zero, we should instead return "Unknown" early.
             */
            if (total == 0) {
                return "unknown";
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
            double rate = double.parse (this.energy_rate);

            if (rate == 0 || this.state.down () == "charging") {
                return "unknown";
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
                return "unknown";
            }
        }
    }

    // This is the publicly accessible class used to probe, enumerate, and inspect power devices
    public class DeviceProber {
        public DeviceProber () {}

        private string type_uint32_to_string (uint32 type_uint32) {
            switch (type_uint32) {
            case 1:  return _("Line Power");
            case 2:  return _("Battery");
            case 3:  return _("UPS");
            case 4:  return _("Monitor");
            case 5:  return _("Mouse");
            case 6:  return _("Keyboard");
            case 7:  return _("PDA");
            case 8:  return _("Phone");
            case 9:  return _("Media Player");
            case 10: return _("Tablet");
            case 11: return _("Computer");
            case 12: return _("Gaming Input");
            case 13: return _("Pen");
            case 14: return _("Touchpad");
            case 15: return _("Modem");
            case 16: return _("Network");
            case 17: return _("Headset");
            case 18: return _("Speakers");
            case 19: return _("Headphones");
            case 20: return _("Video");
            case 21: return _("Other Audio");
            case 22: return _("Remote Control");
            case 23: return _("Printer");
            case 24: return _("Scanner");
            case 25: return _("Camera");
            case 26: return _("Wearable");
            case 27: return _("Toy");
            case 28: return _("Bluetooth Generic");
            default: return "unknown";
            }
        }

        private string technology_uint32_to_string (uint32 technology_uint32) {
            switch (technology_uint32) {
            case 1:  return _("Lithium ion");
            case 2:  return _("Lithium polymer");
            case 3:  return _("Lithium iron phosphate");
            case 4:  return _("Lead acid");
            case 5:  return _("Nickel cadmium");
            case 6:  return _("Nickel metal hydride");
            default: return "unknown";
            }
        }

        private string state_uint32_to_string (uint32 state_uint32) {
            switch (state_uint32) {
            case 1:  return _("Charging");
            case 2:  return _("Discharging");
            case 3:  return _("Empty");
            case 4:  return _("Fully charged");
            case 5:  return _("Pending charge");
            case 6:  return _("Pending discharge");
            default: return "unknown";
            }
        }

        public List<Device> get_devices () throws GLib.Error {
            List<Device> result = new List<Device> ();

            // Create a UPower proxy
            UPower upower = Bus.get_proxy_sync (
                                                BusType.SYSTEM,
                                                "org.freedesktop.UPower",
                                                "/org/freedesktop/UPower"
            );

            ObjectPath[] paths = upower.enumerate_devices ();

            foreach (var path in paths) {
                Device device = this.fetch_device (path);
                result.append (device);
            }

            /* Usually, users will most likely be looking for information regarding their battery.
             * Other devices should listed after batteries.
             * The sorting comparison below moves batteries to the beginning and sorts miscellaneous devices after.
             */
            result.sort ((a, b) => {
                if (a.device_type.down () == "battery" && b.device_type.down () != "battery") {
                    return -1; // a before b
                } else if (a.device_type.down () != "battery" && b.device_type.down () == "battery") {
                    return 1; // b before a
                } else {
                    return strcmp (a.name, b.name); // alphabetical order
                }
            });

            return result;
        }

        public Device fetch_device (string path) throws IOError {
            UPower.Device upower_proxy = Bus.get_proxy_sync (
                                                             BusType.SYSTEM,
                                                             "org.freedesktop.UPower",
                                                             path
            );

            /* Fetch all properties, statistics, and information about the specified device.
             * Should create a `Device` object containing all necessary information.
             */
            Device device = new Device ();

            device.upower_proxy = upower_proxy;
            device.name = upower_proxy.native_path;
            device.path = path;
            device.device_type = this.type_uint32_to_string (upower_proxy.device_type);

            device.vendor = upower_proxy.vendor;
            device.serial = upower_proxy.serial;

            device.model = upower_proxy.model;
            device.technology = this.technology_uint32_to_string (upower_proxy.technology);

            device.capacity = upower_proxy.capacity > 0 ? "%0.3f".printf (upower_proxy.capacity) : "unknown";

            device.charge_control_end_threshold =
                upower_proxy.charge_threshold_enabled && upower_proxy.charge_threshold_supported ?
                upower_proxy.charge_end_threshold.to_string () : "unknown";
            device.charge_cycles = upower_proxy.charge_cycles > 0 ? upower_proxy.charge_cycles.to_string () : "unknown";
            device.state = this.state_uint32_to_string (upower_proxy.state);

            device.energy_full_design = upower_proxy.energy_full_design.to_string ();
            device.energy_full = upower_proxy.energy_full.to_string ();
            device.energy = upower_proxy.energy.to_string ();
            device.energy_rate = upower_proxy.energy_rate.to_string ();

            device.voltage_min_design = upower_proxy.voltage_min_design.to_string ();
            device.voltage = upower_proxy.voltage.to_string ();

            device.icon_name = upower_proxy.icon_name;

            return device;
        }
    }
}
