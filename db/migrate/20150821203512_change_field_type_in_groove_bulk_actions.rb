class ChangeFieldTypeInGrooveBulkActions < ActiveRecord::Migration[5.1]
  def up
    change_column :groove_bulk_actions, :messages, :text
  end

  def down
    change_column :groove_bulk_actions, :messages, :string
  end
end
