#!/bin/bash
#
# !header:start
#
# This file is part of EMMA - http://pyspace.org/EMMA
#
# The name Moodle™ is a registered trademark of the Moodle Trust.
# This package is in no way maintained by the Moodle team.
#
# moodle-maint is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# moodle-maint is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with EMMA.  If not, see <http://www.gnu.org/licenses/>.
#
# (c) 2015 Stephen Parry - sgparry AT mainscreen DOT com
#
# !header:end
#


prefix=/usr/local
source=$(dirname $0)
install -m 755 -d ${prefix}/bin ${prefix}/lib/GEMMA/
install -m 644 ${source}/lib/GEMMA/* ${prefix}/lib/GEMMA/
install -m 755 ${source}/bin/* ${prefix}/bin/
if [ ! -e /etc/GEMMA ]; then
	install -m 755 ${source}/etc/GEMMA /etc
fi
