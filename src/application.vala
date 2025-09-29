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

public class Ampere.Application : Adw.Application {
    public Application () {
        Object (
                application_id: "com.v81d.Ampere",
                flags: ApplicationFlags.DEFAULT_FLAGS,
                resource_base_path: "/com/v81d/Ampere"
        );
    }

    construct {
        ActionEntry[] action_entries = {
            { "about", this.on_about_action },
            { "preferences", this.on_preferences_action },
            { "quit", this.quit }
        };
        this.add_action_entries (action_entries, this);
        this.set_accels_for_action ("app.quit", { "<primary>q" });
    }

    public override void activate () {
        base.activate ();
        var win = this.active_window ?? new Ampere.Window (this);
        win.present ();
    }

    private void on_about_action () {
        string[] developers = { "v81d" };
        var about = new Adw.AboutDialog () {
            application_name = "Ampere",
            application_icon = "com.v81d.Ampere",
            developer_name = "v81d",
            translator_credits = _("translator-credits"),
            version = "0.1.0",
            developers = developers,
            copyright = "© 2025 v81d\n\nThis software is distributed with absolutely no warranty. See the <a href='https://www.gnu.org/licenses/gpl-3.0.html'>GNU General Public License v3.0</a> for full license terms.",
            website = "https://github.com/v81d/ampere",
        };

        about.present (this.active_window);
    }

    private void on_preferences_action () {
        message ("app.preferences action activated");
    }
}
