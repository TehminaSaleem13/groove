require 'rails_helper'

RSpec.describe SettingsController, type: :controller do
  before(:each) do
    sup_ad = FactoryGirl.create(:role, name: 'super_admin1', make_super_admin: true)
    @user = FactoryGirl.create(:user, username: 'new_admin1', role: sup_ad, name: 'testing')
    sign_in @user
    @inv_wh = FactoryGirl.create(:inventory_warehouse, is_default: true)
  end

  context 'Restore from backups' do
    it 'must restore all Products from the backup file' do
      post :restore, method: 'del_import',
                     file: fixture_file_upload(Rails.root.join('/files/restore.zip'))
      [Product, ProductSku, ProductBarcode, ProductImage, ProductCat].each do |klass|
        expect(klass.count).to eq 3
      end
    end
  end

  context 'Export Order Exception' do
    it 'must export order_exceptions' do
      time_now = Time.zone.now
      order = FactoryGirl.create(:order, increment_id: '123-456')
      FactoryGirl.create(
        :order_exception, order: order, user: @user,
                          reason: 'reason', description: 'description'
      )
      xhr :get, :order_exceptions, start: time_now.ago(1.day), end: time_now.end_of_day
      first_record = CSV.parse(response.body)[1]
      match_array = ['reason', 'description', 'testing (new_admin1)']
      expect(match_array - first_record).to eql []
    end
  end

  context 'Export Order Exception' do
    it 'must export order_exceptions' do
      time_now = Time.zone.now
      order = FactoryGirl.create(:order, increment_id: '123-456', packing_user_id: @user.id)
      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, product: product, sku: 'Iphone')
      product_barcode = FactoryGirl.create(:product_barcode, product: product, barcode: '1234567890')
      product_inventory_warehouse = FactoryGirl.create(
        :product_inventory_warehouse, product: product,
                                      inventory_warehouse_id: @inv_wh.id, available_inv: 25)
      order_item = FactoryGirl.create(:order_item, product_id: product.id,
                                                   qty: 1, price: '10', row_total: '10', order: order, name: product.name)
      order_serial = FactoryGirl.create(
        :order_serial, order: order, product: product
      )
      xhr :get, :order_serials, start: time_now.ago(1.day), end: time_now.end_of_day,
                                serial: 'serial'
      first_record = CSV.parse(response.body)[1]
      match_array = [
        order.increment_id, order_serial.serial, product.primary_sku,
        product.primary_barcode, product.name, order_item.price.to_f.to_s, order_item.qty.to_s,
        [order.firstname, order.lastname].join(' '), order.address_1, order.address_2,
        order.city, order.state, order.postcode, order.get_items_count.to_s,
        order.order_placed_time.to_s, order.scanned_on.to_s, product.primary_warehouse.inventory_warehouse.name
      ]
      expect(match_array - first_record).to eql []
    end
  end
end
