/* application.vala
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

public class Wattage.Application : Adw.Application {
  public Application () {
    Object (
            application_id: "io.github.v81d.Wattage",
            flags: ApplicationFlags.DEFAULT_FLAGS,
            resource_base_path: "/io/github/v81d/Wattage"
    );
  }

  construct {
    ActionEntry[] action_entries = {
      { "about", this.on_about_action },
      { "quit", this.quit }
    };
    this.add_action_entries (action_entries, this);
    this.set_accels_for_action ("win.preferences", { "<primary>comma" });
    this.set_accels_for_action ("app.about", { "<primary>i" });
    this.set_accels_for_action ("app.quit", { "<primary>q" });
    this.set_accels_for_action ("win.refresh", { "<primary>r" });
    this.set_accels_for_action ("win.select_next_device", { "Page_Down" });
    this.set_accels_for_action ("win.select_previous_device", { "Page_Up" });
  }

  public override void activate () {
    base.activate ();
    Gtk.Window win = this.active_window ?? new Wattage.Window (this);
    win.present ();
  }

  private void on_about_action () {
    string[] developers = { "v81d" };
    var about = new Adw.AboutDialog () {
      application_name = "Wattage",
      application_icon = "io.github.v81d.Wattage",
      developer_name = "v81d",
      translator_credits = _("translator-credits"),
      version = "1.3.0",
      developers = developers,
      copyright = "© 2025 v81d",
      license_type = Gtk.License.GPL_3_0,
      website = "https://github.com/v81d/wattage",
    };

    about.present (this.active_window);
  }
}
