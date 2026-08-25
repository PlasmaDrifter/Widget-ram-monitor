# RAM Monitor Widget

[![KDE Plasma 6](https://img.shields.io/badge/KDE_Plasma-6.0+-3152A0?style=for-the-badge&logo=kde&logoColor=white)](https://kde.org/plasma-desktop/)
[![QML](https://img.shields.io/badge/UI-QML%2FQt6-41CD52?style=for-the-badge&logo=qt&logoColor=white)](https://doc.qt.io/qt-6/qtqml-index.html)
[![Category](https://img.shields.io/badge/Memory%20Monitor-007AFF?style=for-the-badge&logo=ram&logoColor=white)](https://github.com/PlasmaDrifter)
[![License](https://img.shields.io/badge/License-GPLv2-blue.svg?style=for-the-badge)](LICENSE)

An elegant memory usage gauge and swap monitor for KDE Plasma 6.

---

## Previews

![RAM Monitor Widget Preview](ram-monitor.png)

![RAM Monitor Widget Preview](ram2.png)

![RAM Monitor Widget Preview](desktop-1.png)

---

## Features

- **Active**: RAM usage percentage and gigabyte breakdown
- **Swap**: space monitoring
- **Custom**: warning threshold colors
- **Compact**: and expanded views

## Requirements

- **Environment**: KDE Plasma 6.0 or higher
- **Framework**: Qt6 QML / Plasma Applet API

## Installation

### Option 1: Git Clone (Recommended)
```bash
mkdir -p ~/.local/share/plasma/plasmoids/
git clone https://github.com/PlasmaDrifter/Widget-ram-monitor.git ~/.local/share/plasma/plasmoids/local.widget.ram-monitor
```

### Option 2: Plasma Package Installer
```bash
kpackagetool6 -i ~/.local/share/plasma/plasmoids/local.widget.ram-monitor
```

Then right-click your desktop or panel $\rightarrow$ **Add Widgets...** and search for the widget name.

## Credits & License

- **Author / Maintainer**: PlasmaDrifter
- **License**: Licensed under the [GPLv2](LICENSE).
