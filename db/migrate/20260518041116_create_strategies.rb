class CreateStrategies < ActiveRecord::Migration[8.1]
  def change
    create_table :strategies do |t|
      t.string :name # show name
      t.string :type_name # program data name
      t.text :description
      t.timestamps
    end
  end
end
