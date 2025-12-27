/* chart-drawer.vala
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

using Cairo;
using Gee;

namespace ChartDrawer {
    public class LineGraph {
        public ArrayList<double?> xs { get; set; }
        public ArrayList<double?> ys { get; set; }

        public double? umin_x = null;
        public double? umax_x = null;
        public double? umin_y = null;
        public double? umax_y = null;

        public LineGraph (double? min_x = null, double? max_x = null, double? min_y = null, double? max_y = null) {
            this.xs = new ArrayList<double?> ();
            this.ys = new ArrayList<double?> ();

            this.umin_x = min_x;
            this.umax_x = max_x;
            this.umin_y = min_y;
            this.umax_y = max_y;
        }

        public void plot (double x, double y) {
            this.xs.add (x);
            this.ys.add (y);
        }

        public static void rounded_rect (Context cr,
                                         double x, double y,
                                         double w, double h,
                                         double r) {
            double deg = Math.PI / 180.0;
            cr.new_sub_path ();
            cr.arc (x + w - r, y + r, r, -90 * deg, 0 * deg);
            cr.arc (x + w - r, y + h - r, r, 0 * deg, 90 * deg);
            cr.arc (x + r, y + h - r, r, 90 * deg, 180 * deg);
            cr.arc (x + r, y + r, r, 180 * deg, 270 * deg);
            cr.close_path ();
        }

        private static double sx (double x, double min_x, double max_x, int w) {
            return ((x - min_x) / (max_x - min_x)) * w;
        }

        private static double sy (double y, double min_y, double max_y, int h) {
            return h - ((y - min_y) / (max_y - min_y)) * h;
        }

        public void draw (Context cr, int w, int h) {
            if (xs.size == 0 || ys.size == 0)return;

            double radius = 12;

            // Determine min/max
            double min_x = this.umin_x != null ? (double) this.umin_x : xs.get (0);
            double max_x = this.umax_x != null ? (double) this.umax_x : xs.get (0);
            double min_y = this.umin_y != null ? (double) this.umin_y : ys.get (0);
            double max_y = this.umax_y != null ? (double) this.umax_y : ys.get (0);

            for (int i = 0; i < xs.size; i++) {
                if (this.umin_x == null && xs.get (i) < min_x) {
                    min_x = xs.get (i);
                }

                if (this.umax_x == null && xs.get (i) > max_x) {
                    max_x = xs.get (i);
                }

                if (this.umin_y == null && ys.get (i) < min_y) {
                    min_y = ys.get (i);
                }

                if (this.umax_y == null && ys.get (i) > max_y) {
                    max_y = ys.get (i);
                }
            }

            if (max_x == min_x) {
                max_x = min_x + 1;
            }
            if (max_y == min_y) {
                max_y = min_y + 1;
            }

            // Background
            rounded_rect (cr, 0, 0, w, h, radius);
            cr.set_source_rgba (51 / 255.0, 209 / 255.0, 122 / 255.0, 0.12);
            cr.clip ();

            // Plot area
            cr.rectangle (0, 0, w, h);
            cr.fill ();

            // Area under line
            cr.set_source_rgba (51 / 255.0, 209 / 255.0, 122 / 255.0, 0.25);
            cr.new_path ();
            cr.move_to (sx (xs.get (0), min_x, max_x, w), h);

            for (int i = 0; i < xs.size; i++) {
                cr.line_to (sx (xs.get (i), min_x, max_x, w), sy (ys.get (i), min_y, max_y, h));
            }

            cr.line_to (sx (xs.get (xs.size - 1), min_x, max_x, w), h);
            cr.close_path ();
            cr.fill ();

            // Line
            cr.set_source_rgb (51 / 255.0, 209 / 255.0, 122 / 255.0);
            cr.set_line_width (2.0);
            cr.new_path ();
            cr.move_to (sx (xs.get (0), min_x, max_x, w), sy (ys.get (0), min_y, max_y, h));

            for (int i = 1; i < xs.size; i++) {
                cr.line_to (sx (xs.get (i), min_x, max_x, w), sy (ys.get (i), min_y, max_y, h));
            }

            cr.stroke ();
        }
    }
}
