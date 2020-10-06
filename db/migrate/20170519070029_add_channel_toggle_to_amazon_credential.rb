class AddChannelToggleToAmazonCredential < ActiveRecord::Migration[5.1]
  def change
	   add_column :amazon_credentials, :afn_fulfillment_channel, :boolean, :default => false
       add_column :amazon_credentials, :mfn_fulfillment_channel, :boolean, :default => true
  end
end
