
#
# CBRAIN Project
#
# Single file model
# Represents an entry in the userfile table that corresponds to a single file.
#
# Original author: Tarek Sherif
#
# $Id$
#

require 'fileutils'

#Represents a single file uploaded to the system (as opposed to a FileCollection).
class SingleFile < Userfile
  
  Revision_info="$Id$"

  # Returns a simple keyword identifying the type of
  # the userfile; used mostly by the index view.
  def pretty_type
    ""
  end
  
  #Checks whether the size attribute have been set.
  def size_set?
    ! self.size.blank?
  end
  
  def set_size
    self.set_size! unless self.size_set?
  end

  # Calculates and sets the size attribute.
  def set_size!
    self.size = self.list_files.inject(0){ |total, file_entry|  total += file_entry.size }
    self.save!

    true
  end

end
