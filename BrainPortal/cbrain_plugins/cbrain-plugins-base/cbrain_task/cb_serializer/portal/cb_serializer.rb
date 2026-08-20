
#
# CBRAIN Project
#
# Copyright (C) 2008-2012
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

# A subclass of PortalTask to serialize other tasks.
class CbrainTask::CbSerializer < PortalTask

  Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

  def self.properties #:nodoc:
    {
      :no_presets => true
    }
  end

  # Disabled, not necessary, and costly a little.
  # I want to keep the code around for future use, though.
  #def pretty_name #:nodoc:
  #  prereqs      = self.prerequisites  || {}
  #  for_setup    = prereqs[:for_setup] || {}
  #  ttids        = for_setup.keys   #  [ "T123", "T343" etc ]
  #  tids         = ttids.map { |ttid| ttid[1,999].to_i }
  #  prereq_tasks = CbrainTask.where(id: tids)
  #  grouped      = prereq_tasks.group_by(&:name)
  #  summary      = ""
  #  grouped.each do |name,tasklist|
  #    summary += ", " if ! summary.blank?
  #    summary += "#{name} x #{tasklist.size}"
  #  end
  #  "Serializer (#{summary})"
  #end

  # This method prevents users from trying to launch this interactively,
  # or if launched from the API, ensures that the task IDs are present.
  def after_form #:nodoc:
    if self.params[:ordered_subtask_ids].present? &&
       self.params[:ordered_subtask_ids].is_a?(Array)
      enable_all_subtasks_if_needed()
      check_all_tasks_are_standby()
      return ""
    end

    self.errors.add(:base,
      "This task is missing its list of other Task IDs to serialize.")
    self.errors.add(:base,
      "A CbSerializer is usually started using API calls.")

    "This task cannot be started without a list of task IDs"
  end

  # To make things easier for API calls, they don't have
  # to provide the :task_ids_enabled hash table, we'll fill
  # it for them if needed.
  def enable_all_subtasks_if_needed
    enabled = self.params[:task_ids_enabled] || {}
    self.params[:ordered_subtask_ids].each do |tid|
      enabled[tid.to_s] = "1" if enabled[tid.to_s].nil?
    end
    self.params[:task_ids_enabled] = enabled
  end

  # Validation for after_form.
  def check_all_tasks_are_standby
    tasks = enabled_subtasks()
    not_standby = tasks.count { |task| task.status != 'Standby' }
    if not_standby > 0
      self.errors.add(:base, "Not all tasks are in Standby mode: #{not_standby} wrong out of #{tasks.size}")
    end
  end

  # Sets up everything between the serializer and its dependent subtasks
  def after_final_task_list_saved(tasklist) # we expect tasklist to contain only one CbSerializer?
    tasklist.each do |serializer|
      subtasklist=serializer.enabled_subtasks()
      # Launch the subtasks with prerequisites and the 'Configure Only' meta option
      serializer.rank  = 0
      serializer.level = 0
      serializer.save
      subtasklist.each_with_index do |task,rank|
        task.add_prerequisites_for_post_processing(serializer, 'Completed')
        task.status = 'New' # trigger them to start
        task.rank   = rank+1 unless task.rank
        task.level  = 1 unless task.level
        task.meta[:configure_only]=true
        task.batch_id = serializer.id
        task.save!
      end
    end
    ""
  end

end

