class AddColorToSubject < ActiveRecord::Migration[7.0]
  def up
    add_column :subjects, :color, :string
    Subject.all.each{|su| su.update_column(:color, Subject.generate_color)}
  end

  def down
    remove_column :subjects, :color
  end
end