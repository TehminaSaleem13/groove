class AddToteSetRefToUser < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :tote_set_id, :integer, references: :tote_sets
  end
end
