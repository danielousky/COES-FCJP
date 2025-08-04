class AddSignatoreFieldsToSchools < ActiveRecord::Migration[7.0]
  def change
    add_column :schools, :signatore_name, :string
    add_column :schools, :signatore_position, :string
  end
end
