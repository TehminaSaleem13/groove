class AddNoteToTenants < ActiveRecord::Migration
  def change
    add_column :tenants, :note, :text
  end
end
