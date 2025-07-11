class CreateTimeblocks < ActiveRecord::Migration[7.0]
  def change
    create_table :timeblocks do |t|
      t.integer :day, default: 0
      t.time :start_time, default: '07:00:00'
      t.time :end_time, default: '09:00:00'
      t.integer :modality, default: 0
      t.string :classroom
      t.references :teacher
      t.references :timetable, null: false, foreign_key: true
      t.index [:timetable_id, :day, :start_time], unique: true, name: 'index_timeblocks_on_timetable_and_day_and_start_time'
      t.index [:timetable_id, :day, :end_time], unique: true, name: 'index_timeblocks_on_timetable_and_day_and_end_time'

      # Incluir en nuevos projectos ya que es válido
      # Falla cuando clonas: Habría que incluirlo referente al periodo
      # t.index [:teacher_id, :day, :start_time], unique: true, name: 'index_timeblocks_on_teacher_and_day_and_start_time'
      # t.index [:teacher_id, :day, :end_time], unique: true, name: 'index_timeblocks_on_teacher_and_day_and_end_time'
      # t.index [:teacher_id, :timetable_id, :day, :start_time], unique: true, name: 'index_timeblocks_on_teacher_timetable_day_starttime'
      # t.index [:teacher_id, :timetable_id, :day, :end_time], unique: true, name: 'index_timeblocks_on_teacher_timetable_day_endtime'

      t.timestamps
    end
  end
end