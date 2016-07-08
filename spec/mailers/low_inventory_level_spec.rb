require 'rails_helper'

RSpec.describe LowInventoryLevel do
	before(:each) do
		inv_wh = FactoryGirl.create(:inventory_warehouse, is_default: true)
		store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)

		@product = FactoryGirl.create(:product, :name=>'Apple iPhone 5C')
		product_sku = FactoryGirl.create(:product_sku, :product=> @product, :sku=>'IPHONE5C')
		product_barcode = FactoryGirl.create(:product_barcode, :product=> @product, :barcode=>'1234567891')

		@p_alias = FactoryGirl.create(:product, :name=>'Apple iPhone 5S')
		p_alias_sku = FactoryGirl.create(:product_sku, :product=> @p_alias, :sku=>'IPHONE5S')
		p_alias_barcode = FactoryGirl.create(:product_barcode, :product=> @p_alias, :barcode=>'1234567892')

		Delayed::Worker.delay_jobs = false
		tenant = FactoryGirl.create(:tenant, :name=>"sitetest")
	end

	describe 'low inventry level mailer' do
		context 'notify' do

			let(:mail) { LowInventoryLevel.notify(GeneralSetting.all.first, Apartment::Tenant.current).deliver }

			it 'Should notify user when inventry level goes low through email' do
				general_setting = FactoryGirl.create :low_inventory_alert_settings

				mail.subject.should eq("GroovePacker Low Inventory Alert")
				mail.from.should eq(["app@groovepacker.com"])
				mail.to.should eq([GeneralSetting.all.first.low_inventory_email_address])

				last_delivery = ActionMailer::Base.deliveries.last
				expect(ActionMailer::Base.deliveries.count).to eq(2)
				last_delivery.body.should include "This email was sent to let you know that the following items are currently at or below their low inventory"
			end

			it 'Should notify user when inventry level goes low through email including products' do
				general_setting = FactoryGirl.create :low_inventory_alert_settings

				mail.subject.should eq("GroovePacker Low Inventory Alert")
				mail.from.should eq(["app@groovepacker.com"])
				mail.to.should eq([GeneralSetting.all.first.low_inventory_email_address])

				last_delivery = ActionMailer::Base.deliveries.last
				expect(ActionMailer::Base.deliveries.count).to eq(2)
				last_delivery.body.should include "This email was sent to let you know that the following items are currently at or below their low inventory"
				last_delivery.body.should include "Apple iPhone 5C"
				last_delivery.body.should include "Apple iPhone 5S"
			end

			it 'Should notify user when inventry level goes lower then default limit through email including products' do
				general_setting = FactoryGirl.create( :low_inventory_alert_settings, :default_low_inventory_alert_limit => 10 )

				mail.subject.should eq("GroovePacker Low Inventory Alert")
				mail.from.should eq(["app@groovepacker.com"])
				mail.to.should eq([GeneralSetting.all.first.low_inventory_email_address])

				last_delivery = ActionMailer::Base.deliveries.last
				expect(ActionMailer::Base.deliveries.count).to eq(2)
				last_delivery.body.should include "This email was sent to let you know that the following items are currently at or below their low inventory"
				last_delivery.body.should include "Apple iPhone 5C"
				last_delivery.body.should include "Apple iPhone 5S"
			end

			it 'Should not send mail when low inventory level email set to false' do
				general_setting = FactoryGirl.create( :low_inventory_alert_settings, :low_inventory_alert_email=>false )

				last_delivery = ActionMailer::Base.deliveries.count
				expect(last_delivery).to eq(0)
			end

		end
	end

end
