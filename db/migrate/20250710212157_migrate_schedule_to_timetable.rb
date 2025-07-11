class MigrateScheduleToTimetable < ActiveRecord::Migration[7.0]
  def up
    Section.joins(:schedules).distinct.each do |section|
      timetable = Timetable.create!(section_id: section.id)
      p "Creating timetable for section #{section.id}..."
      section.schedules.each do |schedule|
        begin
          timetable.timeblocks.create!(
            day: schedule.day,
            start_time: schedule.starttime,
            end_time: schedule.endtime,
            classroom: section.classroom,
            teacher_id: section.teacher_id
          )
        rescue Exception => e
          p "Error creating timeblock for section #{section.id}: #{e.message}"
          next
        end 

        
      end
    end
  end

  def down
    Timetable.destroy_all
  end
end