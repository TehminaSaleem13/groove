class CreateToteSets < ActiveRecord::Migration[5.1]
  def change
    create_table :tote_sets do |t|
      t.integer :max_totes, default: 40
      t.string :name

      t.timestamps
    end
  end
end
