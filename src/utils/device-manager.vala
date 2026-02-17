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

using Gee;

using DBusInterface;
using NumericToolkit;

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

    public bool has_history { get; set; }
    public int64? time_to_empty { get; set; }
    public int64? time_to_full { get; set; }
    public double? temperature { get; set; }
    public double? capacity { get; set; }
    public string? icon_name { get; set; }

    public string? health_description { get; set; }

    public DeviceObject () {}

    public bool is_trivial () {
      return vendor == null &&
             model == null &&
             serial == null &&
             technology == null &&
             state == null &&
             energy == null &&
             energy_full == null &&
             energy_full_design == null &&
             energy_rate == null &&
             voltage == null &&
             voltage_min_design == null &&
             charge_cycles == null &&
             charge_start_threshold == null &&
             charge_end_threshold == null &&
             time_to_empty == null &&
             time_to_full == null &&
             temperature == null &&
             capacity == null &&
             health_description == null;
    }
  }

  // This is the publicly accessible class used to probe, enumerate, and inspect power devices
  public class DeviceProber {
    public DeviceProber () {}

    public static string ? stringify_device_type (uint? device_type) {
      if (device_type == null)return null;

      switch (device_type) {
      case 1 : return _("Line Power");
      case 2 : return _("Battery");
      case 3 : return _("UPS");
      case 4 : return _("Monitor");
      case 5 : return _("Mouse");
      case 6 : return _("Keyboard");
      case 7: return _("PDA");
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

    public static string ? stringify_device_technology (uint? device_technology) {
      if (device_technology == null)return null;

      switch (device_technology) {
      case 1: return _("Lithium ion");
      case 2:  return _("Lithium polymer");
      case 3:  return _("Lithium iron phosphate");
      case 4:  return _("Lead acid");
      case 5:  return _("Nickel cadmium");
      case 6:  return _("Nickel metal hydride");
      default: return null;
      }
    }

    public static string ? stringify_device_state (uint? device_state) {
      if (device_state == null)return null;

      switch (device_state) {
      case 1: return _("Charging");
      case 2:  return _("Discharging");
      case 3:  return _("Empty");
      case 4:  return _("Fully charged");
      case 5:  return _("Pending charge");
      case 6:  return _("Pending discharge");
      default: return null;
      }
    }

    public static string ? create_health_description (double? capacity) {
      if (capacity == null)return null;

      if (capacity >= 95)
        return _("The device is near or at its maximum rated capacity. It is in excellent condition and should not require much intervention.");
      else if (capacity >= 90)
        return _("The device performs close to its original capacity. There is little noticeable difference from its optimal state.");
      else if (capacity >= 80)
        return _("The device has lost some capacity, but it should not be of much concern. Continue to take precautions regarding your power device like limiting its charge and using power-saving settings.");
      else if (capacity >= 70)
        return _("The device has noticeably degraded in capacity, but is still usable. Runtime may be shorter than at its original capacity. Use power-optimizing settings to extend longevity and slow down degradation.");
      else if (capacity >= 60)
        return _("The device has experienced a significant drop in capacity. Mobility can be more difficult due to a decrease in runtime. Depending on usage habits, replacement may be necessary in the future.");
      else if (capacity > 0)
        return _("The device has undergone substantial deterioration. Power instability and potential overheating can damage other components. Replace the device to avoid further damage.");

      return null;
    }

    public ArrayList<DeviceObject> get_devices () throws GLib.Error {
      ArrayList<DeviceObject> result = new ArrayList<DeviceObject> ();

      UPower upower = Bus.get_proxy_sync (
                                          BusType.SYSTEM,
                                          "org.freedesktop.UPower",
                                          "/org/freedesktop/UPower"
      );

      ObjectPath[] paths = upower.enumerate_devices ();

      foreach (var path in paths) {
        DeviceObject device = this.fetch_device (path);
        result.add (device);
      }

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
      device.native_path = non_empty_string (upower_proxy.native_path);
      device.vendor = non_empty_string (upower_proxy.vendor);
      device.model = non_empty_string (upower_proxy.model);
      device.serial = non_empty_string (upower_proxy.serial);
      device.device_type = DeviceProber.stringify_device_type (upower_proxy.device_type);
      device.technology = DeviceProber.stringify_device_technology (upower_proxy.technology);
      device.state = DeviceProber.stringify_device_state (upower_proxy.state);
      device.energy = positive_double (upower_proxy.energy);
      device.energy_full = positive_double (upower_proxy.energy_full);
      device.energy_full_design = positive_double (upower_proxy.energy_full_design);
      device.energy_rate = positive_double (upower_proxy.energy_rate);
      device.voltage = positive_double (upower_proxy.voltage);
      device.voltage_min_design = positive_double (upower_proxy.voltage_min_design);
      device.charge_cycles = positive_int32 (upower_proxy.charge_cycles);

      if (upower_proxy.charge_threshold_enabled &&
          upower_proxy.charge_threshold_supported) {
        device.charge_start_threshold = positive_uint32 (upower_proxy.charge_start_threshold);
        device.charge_end_threshold = positive_uint32 (upower_proxy.charge_end_threshold);
      }

      device.has_history = upower_proxy.has_history;
      device.time_to_empty = positive_int64 (upower_proxy.time_to_empty);
      device.time_to_full = positive_int64 (upower_proxy.time_to_full);
      device.temperature = positive_double (upower_proxy.temperature);
      device.capacity = positive_double (upower_proxy.capacity);
      device.icon_name = upower_proxy.icon_name;

      device.health_description = DeviceProber.create_health_description (device.capacity);

      return device;
    }
  }
}
