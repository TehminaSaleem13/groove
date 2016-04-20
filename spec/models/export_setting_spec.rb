require 'rails_helper'

RSpec.describe ExportSetting, :type => :model do
  before(:each) do
    @export_setting = FactoryGirl.build(
      :export_setting,
      send_export_email_on_mon: true,
      time_to_send_export_email: Time.zone.now.since(10.days),
      order_export_email: 'test@gmail.com'
    )

    @general_settings = FactoryGirl.create(:general_setting, :inventory_tracking=>true)
  end

  context 'Schedules Export' do
    it 'when time to export is changed' do
      Delayed::Worker.delay_jobs = true
      expect { @export_setting.save }
        .to change { Delayed::Backend::ActiveRecord::Job.count }.by(1)

      # If already scheduled
      expect { @export_setting.save }
        .to change { Delayed::Backend::ActiveRecord::Job.count }.by(-1)
    end

    it 'should export orders today' do
      day = DateTime.now.strftime('%a')
      @export_setting.send("send_export_email_on_#{day.downcase}=", true)
      @export_setting.save
      expect(@export_setting.should_export_orders_today).to eq true
    end

    it 'should export orders for a given date' do
      day = DateTime.now.strftime('%a')
      @export_setting.send("send_export_email_on_#{day.downcase}=", true)
      @export_setting.save
      # Pass Date
      expect(@export_setting.should_export_orders(DateTime.now)).to eq true
    end
  end

  context 'export data' do
    before(:each) do
      inv_wh = FactoryGirl.create(:inventory_warehouse, is_default: true)
      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      user = FactoryGirl.create :user
      order = FactoryGirl.create(
                                  :order, :status=>'scanned', :increment_id=>'1234567890',
                                  :store => store, scanned_on: DateTime.now,
                                  packing_user_id: user.id
                                  )
      product1 = FactoryGirl.create(:product, is_kit: 1)
      product2 = FactoryGirl.create(:product)
      order_item1 = FactoryGirl.create(:order_item, :product_id=>product1.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product1.name, :inv_status=>'allocated')
      order_item2 = FactoryGirl.create(:order_item, :product_id=>product2.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product2.name, :inv_status=>'allocated')
      product_inv_wh1 = FactoryGirl.create(
        :product_inventory_warehouse, :product=> product1,
        :inventory_warehouse_id =>inv_wh.id,
        :available_inv => 25, :allocated_inv => 5)
      product_inv_wh2 = FactoryGirl.create(
        :product_inventory_warehouse, :product=> product2,
        :inventory_warehouse_id =>inv_wh.id,
        :available_inv => 25, :allocated_inv => 5)
    end

    it 'should export Data' do
      @export_setting.update_attributes(start_time: DateTime.now.ago(5.days), end_time: DateTime.now)
      @export_setting.save
      filename = @export_setting.export_data
      expect(filename).to match(/groove-order-export-#{Time.now.strftime('%Y-%m-%e').to_s}/)
    end
  end
end
