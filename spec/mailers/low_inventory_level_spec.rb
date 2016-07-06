require 'rails_helper'

RSpec.describe LowInventoryLevel do
	before(:each) do
		@inv_wh = FactoryGirl.create(:inventory_warehouse, is_default: true)
	end

	describe 'low inventry level mailer' do
		context 'notify' do

			let(:mail) { LowInventoryLevel.notify(GeneralSetting.all.first, Apartment::Tenant.current).deliver }

			it 'Should notify user when inventry level goes low through email' do
				
				tenant = FactoryGirl.create(:tenant, :name=>"sitetest")

				general_setting = FactoryGirl.create(:general_setting, inventory_tracking: true, 
					low_inventory_alert_email: true, low_inventory_email_address: "test@example.com", 
					hold_orders_due_to_inventory: nil, conf_req_on_notes_to_packer: "never", 
					send_email_for_packer_notes: "never", email_address_for_packer_notes: nil, 
					default_low_inventory_alert_limit: 1, send_email_on_mon: true, send_email_on_tue: true, 
					send_email_on_wed: true, send_email_on_thurs: true, send_email_on_fri: true, 
					send_email_on_sat: true, send_email_on_sun: true, time_to_send_email: "2016-07-06 10:53:00")

				mail.subject.should eq("GroovePacker Low Inventory Alert")
				mail.from.should eq(["app@groovepacker.com"])
				mail.to.should eq([GeneralSetting.all.first.low_inventory_email_address])

        last_delivery = ActionMailer::Base.deliveries.last
        last_delivery.body.should include "This email was sent to let you know that the following items are currently at or below their low inventory"
        # expect(LowInventoryLevel).to receive(:notify).once
      end

    end

  end

end