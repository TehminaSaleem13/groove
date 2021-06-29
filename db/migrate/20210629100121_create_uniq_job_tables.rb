class CreateUniqJobTables < ActiveRecord::Migration[5.1]
  def change
    create_table :uniq_job_tables do |t|
      t.string :worker_id
      t.string :job_timestamp
      t.string :job_id
      t.bigint :job_count, default: 0
      t.timestamps
    end
  end
end
