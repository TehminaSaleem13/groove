require 'rails_helper'

RSpec.describe ExportOrder do
  before(:each) do
    @inv_wh = FactoryGirl.create(:inventory_warehouse, is_default: true)
    Delayed::Worker.delay_jobs = false
  end

  describe 'export order mailer' do
    context 'export' do

      let(:mail) { ExportOrder.export(Apartment::Tenant.current).deliver }

      it 'Should send mail when orders gets exported' do
        general_setting = FactoryGirl.create :general_setting
        export_setting = FactoryGirl.create :export_order_setting

        mail.subject.should eq("GroovePacker Order Export Report")
        mail.from.should eq(["app@groovepacker.com"])
        mail.to.should eq([ExportSetting.all.first.order_export_email])
        mail.attachments.count.should eq(1)

        last_delivery = ActionMailer::Base.deliveries.count
        expect(last_delivery).to eq(1)
      end

      it 'Should not send mail when orders gets exported and auto email export set to false' do
        general_setting = FactoryGirl.create :general_setting
        export_setting = FactoryGirl.create( :export_order_setting, :auto_email_export => false)
        last_delivery = ActionMailer::Base.deliveries.count
        expect(last_delivery).to eq(0)
      end
    end
  end
end
