class CreateTimetables < ActiveRecord::Migration[7.0]
  def change
    create_table :timetables do |t|
      t.string :name
      t.string :color
      t.references :section, null: false, foreign_key: true

      t.timestamps
    end
  end
end