class CreateTotes < ActiveRecord::Migration
  def change
    create_table :totes do |t|
      t.string :name
      t.integer :number
      t.references :order
      t.references :tote_set

      t.timestamps
    end
  end
end
