# Quaklive Statistics (qlstats.tcl)

Quakelive Statistics (qlstats.tcl) is used to get some informations about
playerstatistics from http://quakelive.com/ and post them in the IRC chat.

## Usage

* `+ql <playername>`   Displays a summary of playerstatistics
* `+ql [option] <playername>`

### Options
* `-last`     Displays statistics of the recent match (result, scores, accuracy, etc.)
* `-status`   Does inform you about Quakelive.com online/offline status
* `-help`     Shows this help


## Requirements

* Tcl >=8.5
* fsck 1.17 (available from the same repository)

# License

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2 of the License,
or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

The GPL is written down at http://www.gnu.org/copyleft/gpl.html
