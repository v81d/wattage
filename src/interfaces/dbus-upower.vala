/* dbus-upower.vala
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

namespace DBusInterface {
    [DBus (name = "org.freedesktop.UPower", timeout = 120000)]
    public interface UPower : GLib.Object {
        [DBus (name = "EnumerateDevices")]
        public abstract GLib.ObjectPath[] enumerate_devices () throws DBusError, IOError;

        [DBus (name = "org.freedesktop.UPower.Device", timeout = 120000)]
        public interface Device : GLib.Object {
            [DBus (name = "NativePath")]                        public abstract string native_path { owned get; }
            [DBus (name = "Vendor")]                            public abstract string vendor { owned get; }
            [DBus (name = "Model")]                             public abstract string model { owned get; }
            [DBus (name = "Serial")]                            public abstract string serial { owned get; }

            [DBus (name = "Type")]                              public abstract uint32 device_type { owned get; }
            [DBus (name = "PowerSupply")]                       public abstract bool power_supply { owned get; }
            [DBus (name = "Technology")]                        public abstract uint32 technology { owned get; }

            [DBus (name = "State")]                             public abstract uint32 state { owned get; }
            [DBus (name = "IsPresent")]                         public abstract bool is_present { owned get; }
            [DBus (name = "IsRechargeable")]                    public abstract bool is_rechargeable { owned get; }

            [DBus (name = "Energy")]                            public abstract double energy { owned get; }
            [DBus (name = "EnergyEmpty")]                       public abstract double energy_empty { owned get; }
            [DBus (name = "EnergyFull")]                        public abstract double energy_full { owned get; }
            [DBus (name = "EnergyFullDesign")]                  public abstract double energy_full_design { owned get; }
            [DBus (name = "EnergyRate")]                        public abstract double energy_rate { owned get; }
            [DBus (name = "Voltage")]                           public abstract double voltage { owned get; }
            [DBus (name = "VoltageMinDesign")]                  public abstract double voltage_min_design { owned get; }
            [DBus (name = "VoltageMaxDesign")]                  public abstract double voltage_max_design { owned get; }

            [DBus (name = "ChargeCycles")]                      public abstract int32 charge_cycles { owned get; }
            [DBus (name = "ChargeStartThreshold")]              public abstract uint32 charge_start_threshold { owned get; }
            [DBus (name = "ChargeEndThreshold")]                public abstract uint32 charge_end_threshold { owned get; }
            [DBus (name = "ChargeThresholdEnabled")]            public abstract bool charge_threshold_enabled { owned get; }
            [DBus (name = "ChargeThresholdSupported")]          public abstract bool charge_threshold_supported { owned get; }
            [DBus (name = "ChargeThresholdSettingsSupported")]  public abstract uint32 charge_threshold_settings_supported { owned get; }

            [DBus (name = "HasHistory")]                        public abstract bool has_history { owned get; }
            [DBus (name = "HasStatistics")]                     public abstract bool has_statistics { owned get; }
            [DBus (name = "Online")]                            public abstract bool online { owned get; }
            [DBus (name = "Luminosity")]                        public abstract double luminosity { owned get; }
            [DBus (name = "TimeToEmpty")]                       public abstract int64 time_to_empty { owned get; }
            [DBus (name = "TimeToFull")]                        public abstract int64 time_to_full { owned get; }
            [DBus (name = "Percentage")]                        public abstract double percentage { owned get; }
            [DBus (name = "Temperature")]                       public abstract double temperature { owned get; }
            [DBus (name = "Capacity")]                          public abstract double capacity { owned get; }
            [DBus (name = "WarningLevel")]                      public abstract uint32 warning_level { owned get; }
            [DBus (name = "BatteryLevel")]                      public abstract uint32 battery_level { owned get; }
            [DBus (name = "IconName")]                          public abstract string icon_name { owned get; }
            [DBus (name = "CapacityLevel")]                     public abstract string capacity_level { owned get; }

            [DBus (name = "GetHistory")]
            public abstract HistoryItem[] get_history (string type,
                uint32 timespan,
                uint32 resolution) throws DBusError, IOError;
        }

        public struct HistoryItem {
            public uint32 time;
            public double value;
            public uint32 state;
        }
    }
}
