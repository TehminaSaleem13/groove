class AddImportUserAssignmentsToStores < ActiveRecord::Migration[6.1]
  def change
    add_column :stores, :import_user_assignments, :boolean, default: false
  end
end
