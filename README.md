<img align="left" src="data/icons/hicolor/scalable/apps/io.github.v81d.Wattage.svg" alt="drawing" width="64"/> 

# Wattage

![GitHub commit activity](https://img.shields.io/github/commit-activity/w/v81d/wattage)
![GitHub top language](https://img.shields.io/github/languages/top/v81d/wattage)
![GitHub Issues or Pull Requests](https://img.shields.io/github/issues/v81d/wattage)
![GitHub License](https://img.shields.io/github/license/v81d/wattage)
![GitHub Release](https://img.shields.io/github/v/release/v81d/wattage)

Wattage is an application designed for monitoring the health and status of your power devices. It displays quick data regarding battery capacity, energy metrics, and device information through a clean, modern GTK 4 + libadwaita interface.

![Home page screenshot](demo/screenshot_0.png)
![Preferences page screenshot](demo/screenshot_1.png)

## Features

- Monitor a variety of statistics regarding your battery.
- View battery health, voltage data, model information, manufacturing details, and device status.
- Support for multiple batteries or power sources.
- Interface built with GTK 4 and libadwaita.
- Written in Vala, which is fast since it compiles to C.
- Designed for Linux systems with UPower or sysfs battery information.

## Installation

The following guide provides instructions on how to install Wattage.

### Requirements

- Linux system with battery or power device support.
- And more ... (coming soon!)

### Manual Installation

The recommended way to build and install Wattage is using [GNOME Builder](https://apps.gnome.org/Builder). To get started, follow these instructions (assuming you have already installed Builder):

1. Clone this repository:

```bash
git clone https://github.com/v81d/wattage.git
```

2. Launch Builder and open the cloned repository.
3. Complete the build and installation process in the Build Pipeline tab.
4. Once the process is complete, navigate to the repository folder in your preferred file manager.
5. Install the `io.github.v81d.Wattage.flatpak` file by double-clicking it (Nautilus).

## Contributing

### Reporting Issues
To report an issue or bug, visit Wattage's [issue tracker](https://github.com/v81d/wattage/issues) on GitHub.

### Translating the Project

You can contribute by adding translations for strings in the application. To get started, visit the [translation page](https://app.tolgee.io/projects/23145).

### Pull Requests

To push your features or fixes into this official repository:

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/my-feature`).
3. Commit your changes (`git commit -m "Add new feature"`).
4. Push the branch (`git push origin feature/my-feature`).
5. Open a Pull Request.

## License

Wattage is free software distributed under the **GNU General Public License, version 3.0 or later (GPL-3.0+).**

You are free to use, modify, and share the software under the terms of the GPL.
For full details, see the [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html).
