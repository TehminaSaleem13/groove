class AddNoteToTenants < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :note, :text
  end
end
