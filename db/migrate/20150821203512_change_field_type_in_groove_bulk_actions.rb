class ChangeFieldTypeInGrooveBulkActions < ActiveRecord::Migration
  def up
    change_column :groove_bulk_actions, :messages, :text
  end

  def down
    change_column :groove_bulk_actions, :messages, :string
  end
end
