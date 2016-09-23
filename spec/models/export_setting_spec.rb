require 'rails_helper'

RSpec.describe ExportSetting, :type => :model do
  before(:each) do
    @export_setting = FactoryGirl.build(
      :export_setting,
      send_export_email_on_mon: true,
      time_to_send_export_email: Time.zone.now.since(rand(1..999).days),
      order_export_email: 'success@simulator.amazonses.com'
    )

    @general_settings = FactoryGirl.create(:general_setting, :inventory_tracking=>true)
  end

  context 'Schedules Export' do
    it 'when time to export is changed' do
      Delayed::Worker.delay_jobs = true
      sleep(5)
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

      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode=>"987654321")
      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)
      product2 = FactoryGirl.create(:product)
      order_item2 = FactoryGirl.create(:order_item, :product_id=>product2.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product2.name, :inv_status=>'allocated')
      product_inv_wh1 = FactoryGirl.create(
        :product_inventory_warehouse, :product=> product,
        :inventory_warehouse_id =>inv_wh.id,
        :available_inv => 25, :allocated_inv => 5)
      product_inv_wh2 = FactoryGirl.create(
        :product_inventory_warehouse, :product=> product2,
        :inventory_warehouse_id =>inv_wh.id,
        :available_inv => 25, :allocated_inv => 5)

      scan_pack_setting = ScanPackSetting.new
      scan_pack_setting.escape_string = ''
      scan_pack_setting.save

      order_serial = FactoryGirl.create(:order_serial, order_id: order.id, serial: '5', product_id: product.id)
      product_lot = FactoryGirl.create(:product_lot, product_id: product.id, lot_number: 'LOT')
      FactoryGirl.create(
        :order_item_order_serial_product_lot,
        order_item: order_item,
        order_serial: order_serial,
        product_lot: product_lot
        )
    end

    it 'should export Data without orders' do
      @export_setting.update_attributes(
        start_time: DateTime.now.ago(5.days), end_time: DateTime.now,
        order_export_type: 'do_not_include'
        )
      @export_setting.save
      filename = @export_setting.export_data
      expect(filename).to match(/groove-order-export-#{Time.now.strftime('%Y-%m-%d').to_s}/)
    end

    it 'should export Data including all orders' do
      @export_setting.update_attributes(
        start_time: DateTime.now.ago(5.days), end_time: DateTime.now,
        order_export_type: 'include_all'
        )
      @export_setting.save
      filename = @export_setting.export_data
      expect(filename).to match(/groove-order-export-#{Time.now.strftime('%Y-%m-%d').to_s}/)
    end

    it 'should export Data including orders with serial and lot' do
      @export_setting.update_attributes(
        start_time: DateTime.now.ago(5.days), end_time: DateTime.now,
        order_export_type: 'order_with_serial_lot'
        )
      @export_setting.save
      filename = @export_setting.export_data
      expect(filename).to match(/groove-order-export-#{Time.now.strftime('%Y-%m-%d').to_s}/)
    end
  end
end
