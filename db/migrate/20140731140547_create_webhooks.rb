class CreateWebhooks < ActiveRecord::Migration
  def up
    create_table :webhooks do |t|
    	t.binary :event, :limit => 1.megabyte
      t.timestamps
    end
  end
  def down
  	drop_table :webhooks
  end
end
