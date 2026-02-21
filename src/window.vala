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

using Gee;
using GLib;

using ChartDrawer;
using DBusInterface;
using DeviceManager;
using NumericToolkit;

/* Define the class `DeviceRow`, which inherits from `Gtk.ListBoxRow`.
 * Used as a constructor for a single row in the device list sidebar.
 */
private class DeviceRow : Gtk.ListBoxRow {
  public DeviceObject device { get; private set; }

  public DeviceRow (DeviceObject device) {
    this.device = device;

    Adw.ActionRow row = new Adw.ActionRow ();
    row.set_title (device.native_path);
    row.set_subtitle (device.object_path);

    // Due to the deprecation of `row.icon_name` and `row.set_icon_name ()`, the icon should be prepended as a widget
    Gtk.Image icon = new Gtk.Image.from_icon_name (device.icon_name);
    icon.set_pixel_size (24);
    row.add_prefix (icon);

    this.set_child (row);
  }
}

/* This class inherits from `Gtk.Box`.
 * Used as a constructor for a single section in the device information view.
 */
private class DeviceInfoSection : Gtk.Box {
  public string title { get; private set; }
  private Gtk.ListBox list { private get; private set; }

  public DeviceInfoSection (string title, ArrayList<DeviceInfoSectionData.DeviceProperty> properties) {
    this.title = title;
    this.set_orientation (Gtk.Orientation.VERTICAL);
    this.set_spacing (12);

    Gtk.Label title_label = new Gtk.Label (title);
    title_label.set_halign (Gtk.Align.START);
    title_label.add_css_class ("title-2");
    this.append (title_label);

    this.list = new Gtk.ListBox ();
    this.list.set_selection_mode (Gtk.SelectionMode.NONE);
    this.list.set_hexpand (true);
    this.list.add_css_class ("boxed-list");
    this.append (this.list);

    this.update (properties);
  }

  public void update (ArrayList<DeviceInfoSectionData.DeviceProperty> properties) {
    Gtk.ListBoxRow? row;
    while ((row = this.list.get_row_at_index (0)) != null)
      this.list.remove (row);

    foreach (DeviceInfoSectionData.DeviceProperty property in properties) {
      Adw.ActionRow action_row = new Adw.ActionRow ();
      action_row.set_title (property.name);
      action_row.set_subtitle (property.value);
      action_row.set_subtitle_selectable (true);
      action_row.set_css_classes ({ "property", "monospace" });
      this.list.append (action_row);
    }
  }
}

private class DeviceInfoSectionData {
  public class DeviceProperty {
    public string name { get; set; }
    public string value { get; set; }

    public DeviceProperty (string name, string value) {
      this.name = name;
      this.value = value;
    }
  }

  public string title { get; private set; }
  public ArrayList<DeviceProperty> properties { get; private set; }

  public DeviceInfoSectionData (string title) {
    this.title = title;
    this.properties = new ArrayList<DeviceProperty> ();
  }

  public void set (string name, string? val) {
    if (val != null)this.properties.add (new DeviceProperty (name, val));
  }
}

[GtkTemplate (ui = "/io/github/v81d/Wattage/window.ui")]
public class Wattage.Window : Adw.ApplicationWindow {
  // Bind template children to variables
  [GtkChild] unowned Adw.ToastOverlay main_toast_overlay;
  [GtkChild] unowned Adw.Spinner sidebar_spinner;
  [GtkChild] unowned Adw.Spinner content_spinner;
  [GtkChild] unowned Adw.OverlaySplitView split_view;
  [GtkChild] unowned Gtk.ListBox device_list;
  [GtkChild] unowned Gtk.Box device_info_box;
  [GtkChild] unowned Adw.StatusPage device_list_empty_status;
  [GtkChild] unowned Adw.StatusPage device_info_empty_status;

  private SimpleAction device_history_action;

  private Gtk.Builder preferences_dialog_builder;
  private Settings settings;

  private DeviceProber device_prober;
  private int selected_device_index = 0;
  private ArrayList<DeviceInfoSection> device_info_sections = new ArrayList<DeviceInfoSection> ();

  // Preferences and user settings
  private bool trivial_devices;
  private bool auto_refresh;
  private uint auto_refresh_cooldown;
  private uint auto_refresh_source_id = 0;
  private string energy_unit;
  private string power_unit;
  private string voltage_unit;

  private uint load_device_list_generation = 0;
  private uint load_device_info_generation = 0;
  private uint load_history_widgets_generation = 0;

  private ulong device_history_type_handler_id;
  private ulong device_history_timespan_handler_id;
  private ulong device_history_resolution_handler_id;

  // History preferences
  private string history_type;
  private uint history_timespan;
  private uint history_resolution;

  private Adw.Dialog device_history_dialog;
  private Gtk.Box device_history_main_box;
  private Gtk.Box device_history_box;
  private Adw.ComboRow device_history_type_combo;
  private Adw.SpinRow device_history_timespan_spin;
  private Adw.SpinRow device_history_resolution_spin;

  public Window (Gtk.Application app) {
    Object (application: app);

    this.device_prober = new DeviceProber ();
    this.load_device_list ();

    // This is the handler for selecting a device in the sidebar
    this.device_list.row_selected.connect ((list, row) => {
      if (row is DeviceRow) {
        DeviceRow device_row = (DeviceRow) row;
        this.selected_device_index = device_row.get_index ();
        this.device_info_empty_status.set_visible (false);
        this.device_history_action.set_enabled (true);
        this.load_device_info (device_row.device);
      }
    });

    this.initialize_gsettings ();
    this.initialize_preferences_dialog ();
  }

  construct {
    SimpleAction preferences_action = new SimpleAction ("preferences", null);
    preferences_action.activate.connect (this.on_preferences_action);
    this.add_action (preferences_action);

    SimpleAction refresh_action = new SimpleAction ("refresh", null);
    refresh_action.activate.connect (this.on_refresh_action);
    this.add_action (refresh_action);

    SimpleAction select_next_device_action = new SimpleAction ("select_next_device", null);
    select_next_device_action.activate.connect (this.on_select_next_device_action);
    this.add_action (select_next_device_action);

    SimpleAction select_previous_device_action = new SimpleAction ("select_previous_device", null);
    select_previous_device_action.activate.connect (this.on_select_previous_device_action);
    this.add_action (select_previous_device_action);

    this.device_history_action = new SimpleAction ("device_history", null);
    this.device_history_action.set_enabled (false);
    this.device_history_action.activate.connect (this.on_device_history_action);
    this.add_action (this.device_history_action);
  }

  private void start_auto_refresh () {
    if (!this.auto_refresh || this.auto_refresh_source_id != 0)return;

    this.auto_refresh_source_id = Timeout.add_seconds (this.auto_refresh_cooldown, () => {
      if (!this.auto_refresh) {
        this.auto_refresh_source_id = 0;
        return false;
      }

      this.load_device_list ();
      return true;
    });
  }

  private void stop_auto_refresh () {
    if (this.auto_refresh_source_id != 0) {
      Source.remove (this.auto_refresh_source_id);
      this.auto_refresh_source_id = 0;
    }
  }

  /* This is mostly used for dropdowns in the preferences menu.
   * The function will return the index of a value inside a given array.
   */
  private static int get_string_list_index (Gtk.StringList list, string val) {
    for (int i = 0; i < list.n_items; i++)
      if (list.get_string (i) == val)return i;

    return 0;
  }

  private void initialize_gsettings () {
    this.settings = new Settings ("io.github.v81d.Wattage");

    // Devices
    this.trivial_devices = this.settings.get_boolean ("trivial-devices");

    // Automation
    this.auto_refresh = this.settings.get_boolean ("auto-refresh");
    this.auto_refresh_cooldown = this.settings.get_uint ("auto-refresh-cooldown");

    // Measurements
    this.energy_unit = this.settings.get_string ("energy-unit");
    this.power_unit = this.settings.get_string ("power-unit");
    this.voltage_unit = this.settings.get_string ("voltage-unit");

    // History
    this.history_type = this.settings.get_string ("history-type");
    this.history_timespan = this.settings.get_uint ("history-timespan");
    this.history_resolution = this.settings.get_uint ("history-resolution");
  }

  private void initialize_preferences_dialog () {
    this.preferences_dialog_builder = new Gtk.Builder ();
    try {
      this.preferences_dialog_builder.add_from_resource ("/io/github/v81d/Wattage/preferences-dialog.ui");
    } catch (Error e) {
      stderr.printf ("Could not open preferences dialog: %s\n", e.message);
    }

    // Trivial devices switch
    Adw.SwitchRow trivial_devices_switch = this.preferences_dialog_builder.get_object ("trivial_devices_switch") as Adw.SwitchRow;
    trivial_devices_switch.set_active (this.trivial_devices);
    trivial_devices_switch.notify["active"].connect (() => {
      bool is_active = trivial_devices_switch.get_active ();
      this.settings.set_boolean ("trivial-devices", is_active);
      this.trivial_devices = is_active;
      load_device_list ();
    });

    // Auto-refresh switch
    Adw.SwitchRow auto_refresh_switch = this.preferences_dialog_builder.get_object ("auto_refresh_switch") as Adw.SwitchRow;
    auto_refresh_switch.set_active (this.auto_refresh);

    if (this.auto_refresh)this.start_auto_refresh ();

    auto_refresh_switch.notify["active"].connect (() => {
      bool is_active = auto_refresh_switch.get_active ();
      this.settings.set_boolean ("auto-refresh", is_active);
      this.auto_refresh = is_active;

      if (is_active)this.start_auto_refresh ();
      else this.stop_auto_refresh ();

      load_device_list ();
    });

    // Auto-refresh delay
    Adw.SpinRow auto_refresh_cooldown_row = this.preferences_dialog_builder.get_object ("auto_refresh_cooldown_row") as Adw.SpinRow;
    auto_refresh_cooldown_row.set_value (this.auto_refresh_cooldown);

    auto_refresh_cooldown_row.notify["value"].connect (() => {
      uint cooldown = (uint) auto_refresh_cooldown_row.get_value ();
      this.settings.set_uint ("auto-refresh-cooldown", cooldown);
      this.auto_refresh_cooldown = cooldown;

      // Restart auto-refresh loop
      if (this.auto_refresh) {
        this.stop_auto_refresh ();
        this.start_auto_refresh ();
      }

      load_device_list ();
    });

    // Energy unit
    Adw.ComboRow energy_unit_row = this.preferences_dialog_builder.get_object ("energy_unit") as Adw.ComboRow;
    Gtk.StringList energy_units = (Gtk.StringList) energy_unit_row.get_model ();
    energy_unit_row.set_selected (get_string_list_index (energy_units, this.energy_unit)); // tried to use `.find()` but the compiler keeps saying it doesn't exist for some reason :(
    energy_unit_row.notify["selected"].connect (() => {
      string selected_unit = energy_units.get_string (energy_unit_row.get_selected ());
      this.settings.set_string ("energy-unit", selected_unit);
      this.energy_unit = selected_unit;
      load_device_list ();
    });

    // Power unit
    Adw.ComboRow power_unit_row = this.preferences_dialog_builder.get_object ("power_unit") as Adw.ComboRow;
    Gtk.StringList power_units = (Gtk.StringList) power_unit_row.get_model ();
    power_unit_row.set_selected (get_string_list_index (power_units, this.power_unit));
    power_unit_row.notify["selected"].connect (() => {
      string selected_unit = power_units.get_string (power_unit_row.get_selected ());
      this.settings.set_string ("power-unit", selected_unit);
      this.power_unit = selected_unit;
      load_device_list ();
    });

    // Voltage unit
    Adw.ComboRow voltage_unit_row = this.preferences_dialog_builder.get_object ("voltage_unit") as Adw.ComboRow;
    Gtk.StringList voltage_units = (Gtk.StringList) voltage_unit_row.get_model ();
    voltage_unit_row.set_selected (get_string_list_index (voltage_units, this.voltage_unit));
    voltage_unit_row.notify["selected"].connect (() => {
      string selected_unit = voltage_units.get_string (voltage_unit_row.get_selected ());
      this.settings.set_string ("voltage-unit", selected_unit);
      this.voltage_unit = selected_unit;
      load_device_list ();
    });
  }

  private void initialize_device_history_dialog () {
    this.device_history_dialog = new Adw.Dialog ();
    this.device_history_dialog.set_content_width (640);
    this.device_history_dialog.set_content_height (580);
    this.device_history_dialog.set_title (_("Device History"));

    Adw.ToolbarView toolbar_view = new Adw.ToolbarView ();
    toolbar_view.add_top_bar (new Adw.HeaderBar ());
    this.device_history_dialog.set_child (toolbar_view);

    Gtk.ScrolledWindow scrolled_window = new Gtk.ScrolledWindow ();
    scrolled_window.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
    toolbar_view.set_content (scrolled_window);

    Adw.Clamp clamp = new Adw.Clamp ();
    clamp.set_maximum_size (600);
    clamp.set_tightening_threshold (400);
    scrolled_window.set_child (clamp);

    this.device_history_main_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 24);
    this.device_history_main_box.set_margin_start (12);
    this.device_history_main_box.set_margin_end (12);
    this.device_history_main_box.set_margin_top (12);
    this.device_history_main_box.set_margin_bottom (12);
    clamp.set_child (this.device_history_main_box);

    // History settings and options
    Adw.PreferencesGroup options_group = new Adw.PreferencesGroup ();
    options_group.set_title (_("Options"));
    this.device_history_main_box.append (options_group);

    Gtk.Separator separator = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
    this.device_history_main_box.append (separator);

    this.device_history_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 18);
    this.device_history_main_box.append (this.device_history_box);

    // History types
    this.device_history_type_combo = new Adw.ComboRow ();
    this.device_history_type_combo.set_title (_("Type"));
    this.device_history_type_combo.set_subtitle (_("The type of history to display."));
    this.device_history_type_combo.add_css_class ("combo");

    Gtk.StringList types = new Gtk.StringList ({ _("Rate"), _("Charge") });
    this.device_history_type_combo.set_model (types);
    options_group.add (this.device_history_type_combo);

    // History timespan
    this.device_history_timespan_spin = new Adw.SpinRow.with_range (5, 14400, 1);
    this.device_history_timespan_spin.set_title (_("Timespan"));
    this.device_history_timespan_spin.set_subtitle (_("The timespan, in minutes, to return history data from."));
    options_group.add (this.device_history_timespan_spin);

    // History resolution
    this.device_history_resolution_spin = new Adw.SpinRow.with_range (1, 720, 1);
    this.device_history_resolution_spin.set_title (_("Resolution"));
    this.device_history_resolution_spin.set_subtitle (_("The approximate number of history points to return."));
    options_group.add (this.device_history_resolution_spin);

    this.device_history_type_handler_id = this.device_history_type_combo.notify["selected"].connect (() => {
      string selected_type = this.device_history_type_combo.get_selected () == 0 ? "rate" : "charge";
      this.settings.set_string ("history-type", selected_type);
      this.history_type = selected_type;

      if (this.device_list.get_row_at_index (this.selected_device_index) != null) {
        DeviceRow row = this.device_list.get_row_at_index (this.selected_device_index) as DeviceRow;
        this.load_history_widgets (row.device, this.device_history_main_box, this.device_history_box);
      }
    });

    this.device_history_timespan_handler_id = this.device_history_timespan_spin.notify["value"].connect (() => {
      uint timespan = (uint) this.device_history_timespan_spin.get_value ();
      this.settings.set_uint ("history-timespan", timespan);
      this.history_timespan = timespan;

      if (this.device_list.get_row_at_index (this.selected_device_index) != null) {
        DeviceRow row = this.device_list.get_row_at_index (this.selected_device_index) as DeviceRow;
        this.load_history_widgets (row.device, this.device_history_main_box, this.device_history_box);
      }
    });

    this.device_history_resolution_handler_id = this.device_history_resolution_spin.notify["value"].connect (() => {
      uint resolution = (uint) this.device_history_resolution_spin.get_value ();
      this.settings.set_uint ("history-resolution", resolution);
      this.history_resolution = resolution;

      if (this.device_list.get_row_at_index (this.selected_device_index) != null) {
        DeviceRow row = this.device_list.get_row_at_index (this.selected_device_index) as DeviceRow;
        this.load_history_widgets (row.device, this.device_history_main_box, this.device_history_box);
      }
    });
  }

  private void on_preferences_action () {
    Adw.PreferencesDialog preferences_dialog = this.preferences_dialog_builder.get_object ("preferences_dialog") as Adw.PreferencesDialog;
    preferences_dialog.present (this);
  }

  private static void add_section_metric (DeviceInfoSectionData section,
                                          double? val,
                                          string label,
                                          string unit) {
    if (val != null) {
      double? converted = si_convert (val, unit);
      if (converted != null)
        section.set (label, "%.03f %s".printf (converted, unit));
    }
  }

  private void append_device (DeviceObject device) {
    DeviceRow row = new DeviceRow (device);
    this.device_list.append (row);
  }

  private void load_device_list () {
    uint generation = ++this.load_device_list_generation;

    this.sidebar_spinner.set_visible (true);

    Gtk.ListBoxRow? row;

    while ((row = this.device_list.get_row_at_index (0)) != null)
      this.device_list.remove (row);

    new Thread<void> ("load-device-list", () => {
      ArrayList<DeviceObject> devices;

      try {
        devices = this.device_prober.get_devices ();
        device_list_empty_status.set_visible (false);
        this.device_info_empty_status.set_visible (false);
      } catch (Error e) {
        stderr.printf ("Failed to load power devices: %s\n", e.message);
        devices = new ArrayList<DeviceObject> ();
      }

      Idle.add (() => {
        if (generation != this.load_device_list_generation)return false;

        foreach (DeviceObject device in devices) {
          if (!this.trivial_devices && device.is_trivial ())continue;
          this.append_device (device);
        }

        if (this.device_list.get_row_at_index (this.selected_device_index) != null)
          this.device_list.select_row (this.device_list.get_row_at_index (this.selected_device_index));
        else if (this.device_list.get_row_at_index (0) != null) {
          stdout.printf ("The device at index %s can no longer be found. The first device will be selected as fallback.\n", this.selected_device_index.to_string ());
          this.device_list.select_row (this.device_list.get_row_at_index (0));
        } else {
          stderr.printf ("No power devices have been detected by UPower.\n");
          this.device_list_empty_status.set_visible (true);
          this.device_info_empty_status.set_visible (true);
          this.device_history_action.set_enabled (false);
        }

        this.sidebar_spinner.set_visible (false);

        return false;
      });
    });
  }

  private void load_device_info (DeviceObject device) {
    uint generation = ++this.load_device_info_generation;

    this.content_spinner.set_visible (true);

    new Thread<void> ("load-device-info", () => {
      if (!device.has_history)this.device_history_action.set_enabled (false);

      ArrayList<DeviceInfoSectionData> sections = new ArrayList<DeviceInfoSectionData> ();

      DeviceInfoSectionData general_info = new DeviceInfoSectionData (_("General Information"));
      general_info.set (_("Native Path"), device.native_path);
      general_info.set (_("Object Path"), device.object_path);
      general_info.set (_("Device Type"), device.device_type);
      general_info.set (_("Has History"), device.has_history ? "Yes" : "No");
      sections.add (general_info);

      DeviceInfoSectionData model_details = new DeviceInfoSectionData (_("Model Details"));
      model_details.set (_("Vendor"), device.vendor);
      model_details.set (_("Serial Number"), device.serial);
      model_details.set (_("Model Name"), device.model);
      model_details.set (_("Technology"), device.technology);
      sections.add (model_details);

      DeviceInfoSectionData health_stats = new DeviceInfoSectionData (_("Health Evaluations"));

      if (device.capacity != null)
        health_stats.set (_("State of Health"), "%.03f%%".printf (device.capacity));

      if (device.health_description != null)
        health_stats.set (_("Device Condition"), device.health_description);

      sections.add (health_stats);

      DeviceInfoSectionData charging_status = new DeviceInfoSectionData (_("Charging Status"));

      if (device.charge_start_threshold != null)
        charging_status.set (_("Charge Start Threshold"), "%u%%".printf (device.charge_start_threshold));

      if (device.charge_end_threshold != null)
        charging_status.set (_("Charge End Threshold"), "%u%%".printf (device.charge_end_threshold));

      if (device.charge_cycles != null)
        charging_status.set (_("Cycle Count"), device.charge_cycles.to_string ());

      double? current_charge = calculate_percentage (device.energy, device.energy_full);
      if (current_charge != null)
        charging_status.set (_("Current Charge Percentage"), "%.03f%%".printf (current_charge));

      charging_status.set (_("State"), device.state);

      sections.add (charging_status);

      DeviceInfoSectionData time_calculations = new DeviceInfoSectionData (_("Time Calculations"));

      string? time_to_empty = seconds_to_hms (device.time_to_empty);
      if (time_to_empty != null)
        time_calculations.set (_("Time to Empty"), time_to_empty);

      string? time_to_full = seconds_to_hms (device.time_to_full);
      if (time_to_full != null)
        time_calculations.set (_("Time to Full"), time_to_full);

      if (
          device.energy_full != null &&
          device.energy_rate != null &&
          device.energy_rate > 0 &&
          device.state == _("Discharging")
      ) {
        string? projected_battery_life = seconds_to_hms ((int64) (device.energy_full / device.energy_rate * 3600));
        if (projected_battery_life != null)
          time_calculations.set (_("Projected Battery Life"), projected_battery_life);
      }

      if (
          device.energy_full != null &&
          device.energy_rate != null &&
          device.energy_rate > 0 &&
          device.state == _("Charging")
      ) {
        string? projected_charging_time = seconds_to_hms ((int64) (device.energy_full / device.energy_rate * 3600));
        if (projected_charging_time != null)
          time_calculations.set (_("Projected Charging Time"), projected_charging_time);
      }

      sections.add (time_calculations);

      DeviceInfoSectionData sensor_readings = new DeviceInfoSectionData (_("Sensor Readings"));

      if (device.temperature != null)
        sensor_readings.set (_("Temperature"), "%.03f°C".printf (device.temperature));

      sections.add (sensor_readings);

      DeviceInfoSectionData energy_metrics = new DeviceInfoSectionData (_("Energy Metrics"));

      Window.add_section_metric (energy_metrics, device.energy_full_design,
                                 _("Maximum Rated Capacity"), this.energy_unit);

      Window.add_section_metric (energy_metrics, device.energy_full,
                                 _("Maximum Capacity"), this.energy_unit);

      Window.add_section_metric (energy_metrics, device.energy,
                                 _("Remaining Energy"), this.energy_unit);

      Window.add_section_metric (energy_metrics, device.energy_rate,
                                 _("Net Energy Rate"), this.power_unit);

      sections.add (energy_metrics);

      DeviceInfoSectionData voltage_stats = new DeviceInfoSectionData (_("Voltage Statistics"));

      if (device.voltage_min_design != null) {
        double? converted = si_convert (device.voltage_min_design, this.voltage_unit);
        if (converted != null)
          voltage_stats.set (_("Minimum Rated Voltage"), "%.03f %s".printf (converted, this.voltage_unit));
      }

      if (device.voltage != null) {
        double? converted = si_convert (device.voltage, this.voltage_unit);
        if (converted != null)
          voltage_stats.set (_("Current Voltage"), "%.03f %s".printf (converted, this.voltage_unit));
      }

      sections.add (voltage_stats);

      Idle.add (() => {
        if (generation != this.load_device_info_generation)return false;

        ArrayList<string> existing_titles = new ArrayList<string> ();
        foreach (DeviceInfoSection section in this.device_info_sections)existing_titles.add (section.title);

        ArrayList<string> new_titles = new ArrayList<string> ();
        foreach (DeviceInfoSectionData section in sections)
          if (section.properties.size > 0)new_titles.add (section.title);

        // Check if both title arrays match
        bool titles_match = false;

        if (existing_titles.size == new_titles.size) {
          titles_match = true;
          for (int i = 0; i < existing_titles.size; i++) {
            if (existing_titles.get (i) != new_titles.get (i)) {
              titles_match = false;
              break;
            }
          }
        }

        /* We should reconstruct the entire content view if the two arrays do not match.
         * If we were to simply append the missing sections, they would be added directly
         * to the end of the content, which is not always desired. Rebuilding the view
         * would be the simplest way to resolve this. If the two arrays do match, however,
         * we should just update existing sections in place.
         */
        if (titles_match) {
          foreach (DeviceInfoSectionData section in sections) {
            if (section.properties.size == 0)continue;

            // Match existing sections by title
            DeviceInfoSection ? existing_section = null;
            foreach (DeviceInfoSection s in this.device_info_sections) {
              if (s.title == section.title) {
                existing_section = s;
                break;
              }
            }

            if (existing_section != null)existing_section.update (section.properties);
          }
        } else {
          foreach (DeviceInfoSection s in this.device_info_sections)this.device_info_box.remove (s);
          this.device_info_sections.clear ();

          foreach (DeviceInfoSectionData section in sections) {
            if (section.properties.size == 0)continue;

            DeviceInfoSection s = new DeviceInfoSection (section.title, section.properties);
            this.device_info_box.append (s);
            this.device_info_sections.add (s);
          }
        }

        this.content_spinner.set_visible (false);
        this.device_info_empty_status.set_visible (this.device_info_sections.size == 0);

        return false;
      });
    });
  }

  private void load_history_widgets (DeviceObject device, Gtk.Box main_box, Gtk.Box history_box) {
    uint generation = ++this.load_history_widgets_generation;

    // Clear all of the history box's children
    while (history_box.get_first_child () != null) {
      history_box.remove (history_box.get_first_child ());
    }

    new Thread<void> ("load-history-widgets", () => {
      UPower.HistoryItem[] history_items;
      Error e; // must declare this for some reason because the compiler keeps complaining

      try {
        history_items = device.upower_proxy.get_history (this.history_type,
                                                         this.history_timespan * 60,
                                                         this.history_resolution);
      } catch (Error e) {
        Idle.add (() => {
          if (generation != this.load_history_widgets_generation)return false;

          while (main_box.get_first_child () != null) {
            main_box.remove (main_box.get_first_child ());
          }

          stderr.printf ("Error getting device history: %s\n", e.message);

          Adw.StatusPage status_page = new Adw.StatusPage ();
          status_page.set_hexpand (true);
          status_page.set_vexpand (true);
          status_page.set_title (_("History Unavailable"));
          status_page.set_description (e.message);
          status_page.set_icon_name ("dialog-error-symbolic");
          main_box.append (status_page);

          return false;
        });

        return;
      }

      ArrayList<UPower.HistoryItem?> history_sorted = new ArrayList<UPower.HistoryItem?> ();
      foreach (UPower.HistoryItem item in history_items)history_sorted.add (item);

      // Sort in chronological order
      history_sorted.sort ((a, b) => {
        if (a.time < b.time)return -1; // `a` before `b`
        if (a.time > b.time)return 1; // `b` before `a`
        return 0;
      });

      Idle.add (() => {
        if (generation != this.load_history_widgets_generation)return false;

        uint count = 0;

        Adw.ExpanderRow expander_row = new Adw.ExpanderRow ();
        expander_row.set_title (_("Entries"));

        Gtk.DrawingArea drawing_area = new Gtk.DrawingArea ();
        drawing_area.set_size_request (-1, 150);

        LineGraph graph = new LineGraph (null,
                                         null,
                                         0,
                                         this.history_type == "charge" ? (double?) 100 : null);
        drawing_area.set_draw_func ((widget, cr, width, height) => graph.draw (cr, width, height));

        foreach (UPower.HistoryItem item in history_sorted) {
          string state = DeviceProber.stringify_device_state (item.state);
          if (state == null)continue;

          count++;

          DateTime dt = new DateTime.from_unix_local (item.time);
          string timestamp = dt.format ("%c");

          double val = double.parse ("%.3f".printf (item.value));

          Adw.ActionRow row = new Adw.ActionRow ();
          row.set_title (timestamp);

          switch (this.history_type) {
            case "rate" :
              row.set_subtitle ("Rate: %.3f %s (%s)".printf (si_convert (val, this.power_unit),
                                                             this.power_unit,
                                                             state.down ()));
              break;
            case "charge" :
              row.set_subtitle ("Charge: %.3f%% (%s)".printf (val, state.down ()));
              break;
          }

          Gtk.Label placement_label = new Gtk.Label (count.to_string ());
          placement_label.add_css_class ("monospace");
          row.add_suffix (placement_label);

          expander_row.add_row (row);

          double x = (double) item.time - (double) history_sorted.get (0).time;
          double y = val;

          graph.plot (x, y);
        }

        if (count == 0) {
          Gtk.Label label = new Gtk.Label (_("No history entries available within the configured timespan and resolution."));
          label.set_halign (Gtk.Align.START);
          history_box.append (label);
        } else {
          Gtk.Box result_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 18);
          result_box.set_hexpand (true);
          result_box.set_vexpand (true);

          if (count == 1) {
            Gtk.Label label = new Gtk.Label (_("There are not enough history entries to display a graph."));
            label.set_halign (Gtk.Align.START);
            result_box.append (label);
          } else result_box.append (drawing_area);

          Gtk.ListBox list_box = new Gtk.ListBox ();
          list_box.set_selection_mode (Gtk.SelectionMode.NONE);
          list_box.add_css_class ("boxed-list");
          list_box.append (expander_row);
          result_box.append (list_box);

          expander_row.set_subtitle (_("%u history item(s) discovered.").printf (count));

          history_box.append (result_box);
        }

        return false;
      });
    });
  }

  // Display device history dialog
  public void on_device_history_action () {
    if (this.device_list.get_row_at_index (this.selected_device_index) == null) {
      this.main_toast_overlay.add_toast (new Adw.Toast (_("No device is currently selected.")));
      return;
    }

    DeviceRow device_row = this.device_list.get_row_at_index (this.selected_device_index) as DeviceRow;
    DeviceObject device = device_row.device;

    if (this.device_history_dialog == null) {
      this.initialize_device_history_dialog ();
    }

    this.device_history_type_combo.set_selected (this.history_type == "charge" ? 1 : 0);
    this.device_history_timespan_spin.set_value (this.history_timespan);
    this.device_history_resolution_spin.set_value (this.history_resolution);

    this.load_history_widgets (device, this.device_history_main_box, this.device_history_box);

    this.device_history_dialog.present (this);
  }

  [GtkCallback]
  public void on_toggle_sidebar_toggled (Gtk.ToggleButton button) {
    bool is_active = button.get_active ();
    this.split_view.set_show_sidebar (is_active);
  }

  // Keyboard shortcut select next device action
  private void on_select_next_device_action () {
    if (this.device_list.get_selected_row () != this.device_list.get_last_child ())
      this.device_list.select_row (this.device_list.get_row_at_index (this.selected_device_index + 1));
  }

  // Keyboard shortcut select previous device action
  private void on_select_previous_device_action () {
    if (this.device_list.get_selected_row () != this.device_list.get_first_child ())
      this.device_list.select_row (this.device_list.get_row_at_index (this.selected_device_index - 1));
  }

  // Keyboard shortcut refresh action
  private void on_refresh_action () {
    load_device_list ();
  }

  // Refresh button clicked action
  [GtkCallback]
  public void on_refresh_clicked (Gtk.Button _) {
    load_device_list ();
  }
}
