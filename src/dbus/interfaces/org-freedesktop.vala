using GLib;

namespace org {
	namespace freedesktop {
		[DBus (name = "org.freedesktop.UPower", timeout = 120000)]
		public interface UPower : GLib.Object {
			[DBus (name = "EnumerateDevices")]
			public abstract async GLib.ObjectPath[] enumerate_devices () throws DBusError, IOError;

            /* The following is not needed for Wattage as of now.
			[DBus (name = "GetDisplayDevice")]
			public abstract async GLib.ObjectPath get_display_device () throws DBusError, IOError;

			[DBus (name = "GetCriticalAction")]
			public abstract async string get_critical_action () throws DBusError, IOError;

			[DBus (name = "DeviceAdded")]
			public signal void device_added(GLib.ObjectPath device);

			[DBus (name = "DeviceRemoved")]
			public signal void device_removed(GLib.ObjectPath device);

			[DBus (name = "DaemonVersion")]
			public abstract string daemon_version { owned get; }

			[DBus (name = "OnBattery")]
			public abstract bool on_battery { get; }

			[DBus (name = "LidIsClosed")]
			public abstract bool lid_is_closed { get; }

			[DBus (name = "LidIsPresent")]
			public abstract bool lid_is_present { get; }
			*/
		}

		[DBus (name = "org.freedesktop.UPower", timeout = 120000)]
		public interface UPowerSync : GLib.Object {
			[DBus (name = "EnumerateDevices")]
			public abstract GLib.ObjectPath[] enumerate_devices () throws DBusError, IOError;

            /* The following is not needed for Wattage as of now.
			[DBus (name = "GetDisplayDevice")]
			public abstract GLib.ObjectPath get_display_device () throws DBusError, IOError;

			[DBus (name = "GetCriticalAction")]
			public abstract string get_critical_action () throws DBusError, IOError;

			[DBus (name = "DeviceAdded")]
			public signal void device_added(GLib.ObjectPath device);

			[DBus (name = "DeviceRemoved")]
			public signal void device_removed(GLib.ObjectPath device);

			[DBus (name = "DaemonVersion")]
			public abstract string daemon_version { owned get; }

			[DBus (name = "OnBattery")]
			public abstract bool on_battery { get; }

			[DBus (name = "LidIsClosed")]
			public abstract bool lid_is_closed { get; }

			[DBus (name = "LidIsPresent")]
			public abstract bool lid_is_present { get; }
			*/
		}

		[DBus (name = "org.freedesktop.UPower.Device", timeout = 120000)]
		public interface UPowerDevice : GLib.Object {
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
}
