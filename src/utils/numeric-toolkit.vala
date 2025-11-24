/* numeric-toolkit.vala
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

namespace NumericToolkit {
    public static double ? si_convert (double? value, string? unit) {
        if (value == null || unit == null || unit.length == 0) {
            return value;
        }

        double factor = 1.0;

        if (unit.has_prefix ("p")) {
            factor = 1e12;
        } else if (unit.has_prefix ("n")) {
            factor = 1e9;
        } else if (unit.has_prefix ("μ") || unit.has_prefix ("µ")) { // mu or micro
            factor = 1e6;
        } else if (unit.has_prefix ("m")) {
            factor = 1e3;
        } else if (unit.has_prefix ("c")) {
            factor = 1e2;
        } else if (unit.has_prefix ("d")) {
            factor = 1e1;
        } else if (unit.has_prefix ("k")) {
            factor = 1e-3;
        } else if (unit.has_prefix ("M")) {
            factor = 1e-6;
        } else if (unit.has_prefix ("G")) {
            factor = 1e-9;
        } else if (unit.has_prefix ("J")) {
            factor = 3600;
        }

        return value * factor;
    }

    public static double ? calculate_percentage (double? part, double? total) {
        /* In some special cases, the total may be 0.
         * To avoid division by zero, we should instead return `null` early.
         */
        if (part == null || total == null || total == 0 || total.is_nan () || !total.is_finite ()) {
            return null;
        }

        return (part / total) * 100;
    }

    public static string ? seconds_to_hms (int64? seconds) {
        if (seconds == null) {
            return null;
        }

        int64 result_hours = seconds / 3600;
        int64 result_seconds = seconds - result_hours * 3600;
        int64 result_minutes = result_seconds / 60;
        result_seconds -= result_minutes * 60;

        string format = "%02" + int64.FORMAT + ":%02" + int64.FORMAT + ":%02" + int64.FORMAT;
        return format.printf (result_hours, result_minutes, result_seconds);
    }
}
