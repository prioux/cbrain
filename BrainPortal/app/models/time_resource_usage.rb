
#
# CBRAIN Project
#
# Copyright (C) 2008-2019
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# Tracks creation, delete, increases and decreases of various time resources.
# Abstract class, more specific subclasses are to be used.
#
# I doubt we'll ever get negative consumption values...
class TimeResourceUsage < ResourceUsage

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  cbrain_abstract_model! # objects of this class are not to be instanciated

end

