class CreateGroovepackerWebhooks < ActiveRecord::Migration[5.1]
  def change
    create_table :groovepacker_webhooks do |t|
      t.string :secret_key
      t.string :url
      t.string :event

      t.timestamps
    end
  end
end
