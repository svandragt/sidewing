#!/bin/sh

# <xbar.title>Clock</xbar.title>
# <xbar.version>1.0</xbar.version>
# <xbar.author>Sidewing</xbar.author>
# <xbar.desc>Shows the current time, with the weekday and date.</xbar.desc>
# <xbar.dependencies>date</xbar.dependencies>

set -eu

# 10s keeps the minute at most 10s late; a 1m refresh can lag by up to 59s.
date "+%a, %-d %b   %H:%M"
