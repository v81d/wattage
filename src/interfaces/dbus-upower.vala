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

namespace org {
    namespace freedesktop {
        [DBus (name = "org.freedesktop.UPower", timeout = 120000)]
        public interface UPower : GLib.Object {
            [DBus (name = "EnumerateDevices")]
            public abstract async GLib.ObjectPath[] enumerate_devices () throws DBusError, IOError;

            [DBus (name = "org.freedesktop.UPower.Device", timeout = 120000)]
            public interface Device : GLib.Object {
                // General information
                [DBus (name = "NativePath")]
                public abstract string native_path { owned get; }

                // Manufacturing details
                [DBus (name = "Vendor")]
                public abstract string manufacturer { owned get; }

                // Model information
                [DBus (name = "Model")]
                public abstract string model { owned get; }

                [DBus (name = "Serial")]
                public abstract string serial { owned get; }

                // Health evaluations
                [DBus (name = "Capacity")]
                public abstract double capacity { owned get; }
            }
        }

        [DBus (name = "org.freedesktop.UPower", timeout = 120000)]
        public interface UPowerSync : GLib.Object {
            [DBus (name = "EnumerateDevices")]
            public abstract GLib.ObjectPath[] enumerate_devices () throws DBusError, IOError;
        }
    }
}
