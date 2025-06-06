
#
# CBRAIN Project
#
# Copyright (C) 2008-2025
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

class DropTaskVmAllocations < ActiveRecord::Migration[5.0]
  def up
    drop_table :task_vm_allocations
  end

  def down
    create_table :task_vm_allocations do |t|
      t.integer :vm_id
      t.integer :task_id
      t.timestamps
    end
  end
end