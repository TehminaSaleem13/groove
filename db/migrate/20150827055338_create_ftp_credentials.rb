class CreateFtpCredentials < ActiveRecord::Migration
  def up
    create_table :ftp_credentials do |t|
      t.string   "host",      :defaule => ""
      t.integer  "port",      :default => 21
      t.string   "username",  :default => ""
      t.string   "password",  :default => ""
      t.references :store,                    :null => false

      t.timestamps
    end
  end

  def down
    drop_table :ftp_credentials
  end
end
