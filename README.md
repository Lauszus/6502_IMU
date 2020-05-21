# 6502 IMU

#### Developed by Kristian Sloth Lauszus, 2020

The code is released under the MIT License.
_________
[![](https://github.com/Lauszus/6502_IMU/workflows/CI/badge.svg)](https://github.com/Lauszus/6502_IMU/actions?query=branch%3Amaster)

6502 code for estimating roll and pitch using a [MPU-6500](https://invensense.tdk.com/products/motion-tracking/6-axis/mpu-6500/).

## Hardware

The hardware is based on Ben Eater's excellent YouTube video series: <https://eater.net/6502>.

The original schematic can be found in [docs/6502.png](docs/6502.png).

The switches on PA0-PA3 has been removed and are used for bit baning SPI. This is used for communicating with a MPU-6500.

The pins are connected according to the following table:

| 6502 |  MPU-6500  |
|------|------------|
| PA0  | CLK        |
| PA1  | MOSI (SDI) |
| PA2  | MISO (SDO) |
| PA3  | CS (NCS)   |
| NMI  | INT        |

Furthermore an optional LED can be connected to PA4.

## Software

To build and flash the application simply run:

```bash
make flash
```

### vasm


The [vasm](sun.hasenbraten.de/vasm/) assembler is used.

The latest release can be downloaded here: <http://sun.hasenbraten.de/vasm/index.php?view=relsrc>.

The code is compiled for the `6502` CPU and is using the `oldstyle` syntax module:

```bash
make CPU=6502 SYNTAX=oldstyle
sudo cp vasm6502_oldstyle /usr/local/bin/
```

More compilations instructions can be found here: <http://sun.hasenbraten.de/vasm/index.php?view=compile>

### minipro

[minipro](https://gitlab.com/DavidGriffith/minipro) is used for programming the EEPROM.

It can be compiled and installed on a Debian/Ubuntu system like so:

```bash
sudo apt install build-essential pkg-config git libusb-1.0-0-dev
git clone https://gitlab.com/DavidGriffith/minipro.git
cd minipro
make
sudo make install
sudo cp udev/*.rules /etc/udev/rules.d/
sudo udevadm trigger
sudo usermod -a -G plugdev $USER
```

For more information see the [minipro README](https://gitlab.com/DavidGriffith/minipro/-/blob/master/README.md)
