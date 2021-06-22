class AddImportJobStatusToTenants < ActiveRecord::Migration[5.1]
  def change
    add_column :tenants, :import_job_status, :string
  end
end
