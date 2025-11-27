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
using NumericToolkit;
using DBusInterface;

namespace DeviceManager {
    // This class is used to represent basic information about a single device
    public class DeviceObject {
        public UPower.Device upower_proxy { get; set; }

        public ObjectPath? object_path { get; set; }

        public string? native_path { get; set; }
        public string? vendor { get; set; }
        public string? model { get; set; }
        public string? serial { get; set; }

        public string? device_type { get; set; }
        public string? technology { get; set; }

        public string? state { get; set; }

        public double? energy { get; set; }
        public double? energy_full { get; set; }
        public double? energy_full_design { get; set; }
        public double? energy_rate { get; set; }
        public double? voltage { get; set; }
        public double? voltage_min_design { get; set; }

        public int32? charge_cycles { get; set; }
        public uint32? charge_start_threshold { get; set; }
        public uint32? charge_end_threshold { get; set; }

        public int64? time_to_empty { get; set; }
        public int64? time_to_full { get; set; }
        public double? temperature { get; set; }
        public double? capacity { get; set; }
        public string? icon_name { get; set; }

        public DeviceObject () {}

        public string ? create_health_alert () {
            if (this.capacity == null) {
                return null;
            }

            if (this.capacity >= 95) {
                return _("The device is near or at its maximum rated capacity. It is in excellent condition and should not require much intervention.");
            } else if (this.capacity >= 90) {
                return _("The device performs close to its original capacity. There is little noticeable difference from its optimal state.");
            } else if (this.capacity >= 80) {
                return _("The device has lost some capacity, but it should not be of much concern. Continue to take precautions regarding your power device like limiting its charge and using power-saving settings.");
            } else if (this.capacity >= 70) {
                return _("The device has noticeably degraded in capacity, but is still usable. Runtime may be shorter than at its original capacity. Use power-optimizing settings to extend longevity and slow down degradation.");
            } else if (this.capacity >= 60) {
                return _("The device has experienced a significant drop in capacity. Mobility can be more difficult due to a decrease in runtime. Depending on usage habits, replacement may be necessary in the future.");
            } else if (this.capacity > 0) {
                return _("The device has undergone substantial deterioration. Power instability and potential overheating can damage other components. Replace the device to avoid further damage.");
            } else {
                return null;
            }
        }
    }

    // This is the publicly accessible class used to probe, enumerate, and inspect power devices
    public class DeviceProber {
        public DeviceProber () {}

        private string ? up_device_type (uint32? device_type) {
            if (device_type == null) {
                return null;
            }

            switch (device_type) {
            case 1 : return _("Line Power");
            case 2 : return _("Battery");
            case 3 : return _("UPS");
            case 4 : return _("Monitor");
            case 5 : return _("Mouse");
            case 6 : return _("Keyboard");
            case 7 : return _("PDA");
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
            default: return null;
            }
        }

        private string ? up_device_technology (uint32? device_technology) {
            if (device_technology == null) {
                return null;
            }

            switch (device_technology) {
            case 1 : return _("Lithium ion");
            case 2:  return _("Lithium polymer");
            case 3:  return _("Lithium iron phosphate");
            case 4:  return _("Lead acid");
            case 5:  return _("Nickel cadmium");
            case 6:  return _("Nickel metal hydride");
            default: return null;
            }
        }

        private string ? up_device_state (uint32? device_state) {
            if (device_state == null) {
                return null;
            }

            switch (device_state) {
            case 1 : return _("Charging");
            case 2:  return _("Discharging");
            case 3:  return _("Empty");
            case 4:  return _("Fully charged");
            case 5:  return _("Pending charge");
            case 6:  return _("Pending discharge");
            default: return null;
            }
        }

        public List<DeviceObject> get_devices () throws GLib.Error {
            List<DeviceObject> result = new List<DeviceObject> ();

            // Create a UPower proxy
            UPower upower = Bus.get_proxy_sync (
                                                BusType.SYSTEM,
                                                "org.freedesktop.UPower",
                                                "/org/freedesktop/UPower"
            );

            ObjectPath[] paths = upower.enumerate_devices ();

            foreach (var path in paths) {
                DeviceObject device = this.fetch_device (path);
                result.append (device);
            }

            /* Usually, users will most likely be looking for information regarding their battery.
             * Other devices should listed after batteries.
             * The sorting comparison below moves batteries to the beginning and sorts miscellaneous devices after.
             */
            result.sort ((a, b) => {
                string a_type = a.device_type != null ? a.device_type.down () : "";
                string b_type = b.device_type != null ? b.device_type.down () : "";

                if (a_type == "battery" && b_type != "battery") {
                    return -1; // a before b
                } else if (a_type != "battery" && b_type == "battery") {
                    return 1; // b before a
                } else {
                    string a_path = a.native_path ?? "";
                    string b_path = b.native_path ?? "";
                    return strcmp (a_path, b_path);
                }
            });

            return result;
        }

        public DeviceObject fetch_device (ObjectPath object_path) throws IOError {
            UPower.Device upower_proxy = Bus.get_proxy_sync (
                                                             BusType.SYSTEM,
                                                             "org.freedesktop.UPower",
                                                             object_path
            );

            DeviceObject device = new DeviceObject ();
            device.upower_proxy = upower_proxy;
            device.object_path = object_path;

            device.native_path = upower_proxy.native_path.length > 0 ? (string?) upower_proxy.native_path : null;
            device.vendor = upower_proxy.vendor.length > 0 ? (string?) upower_proxy.vendor : null;
            device.model = upower_proxy.model.length > 0 ? (string?) upower_proxy.model : null;
            device.serial = upower_proxy.serial.length > 0 ? (string?) upower_proxy.serial : null;

            device.device_type = this.up_device_type (upower_proxy.device_type);
            device.technology = this.up_device_technology (upower_proxy.technology);
            device.state = this.up_device_state (upower_proxy.state);

            device.energy = upower_proxy.energy > 0 ? (double?) upower_proxy.energy : null;
            device.energy_full = upower_proxy.energy_full > 0 ? (double?) upower_proxy.energy_full : null;
            device.energy_full_design = upower_proxy.energy_full_design > 0 ? (double?) upower_proxy.energy_full_design : null;
            device.energy_rate = upower_proxy.energy_rate > 0 ? (double?) upower_proxy.energy_rate : null;
            device.voltage = upower_proxy.voltage > 0 ? (double?) upower_proxy.voltage : null;
            device.voltage_min_design = upower_proxy.voltage_min_design > 0 ? (double?) upower_proxy.voltage_min_design : null;

            device.charge_cycles = upower_proxy.charge_cycles > 0 ? (int32?) upower_proxy.charge_cycles : null;

            if (upower_proxy.charge_threshold_enabled && upower_proxy.charge_threshold_enabled
                && upower_proxy.charge_threshold_supported) {
                device.charge_start_threshold = upower_proxy.charge_start_threshold > 0 ? (uint32?) upower_proxy.charge_start_threshold : null;
                device.charge_end_threshold = upower_proxy.charge_end_threshold > 0 ? (uint32?) upower_proxy.charge_end_threshold : null;
            }

            device.time_to_empty = upower_proxy.time_to_empty > 0 ? (int64?) upower_proxy.time_to_empty : null;
            device.time_to_full = upower_proxy.time_to_full > 0 ? (int64?) upower_proxy.time_to_full : null;
            device.temperature = upower_proxy.temperature > 0 ? (double?) upower_proxy.temperature : null;
            device.capacity = upower_proxy.capacity > 0 ? (double?) upower_proxy.capacity : null;

            device.icon_name = upower_proxy.icon_name;

            return device;
        }
    }
}
