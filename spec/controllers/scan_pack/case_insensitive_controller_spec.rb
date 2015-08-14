require 'rails_helper'
#include Devise::TestHelpers

RSpec.describe ScanPackController, :type => :controller do

  before(:each) do
    Groovepacker::SeedTenant.new.seed
    @scanpacksetting = ScanPackSetting.first
    @scanpacksetting.post_scanning_option = "Record"
    @scanpacksetting.save
    @generalsetting = GeneralSetting.all.first
    @generalsetting.update_column(:inventory_tracking, true)

    #@user_role =FactoryGirl.create(:role, :name=>'scan_pack', :import_orders=>true)
    @user = FactoryGirl.create(:user, :username=>"scan_pack_spec_user", :name=>'Scan Pack user', 
      :role => Role.find_by_name('Scan & Pack User'))
    # sign_in @user
    request.env["devise.mapping"] = Devise.mappings[:user]
    sign_in :user, @user 

    #@request.env["devise.mapping"] = Devise.mappings[:user]

    @child_item_l = lambda do |name, images, sku, qty_remaining,
      scanned_qty, packing_placement, kit_packing_placement,
      barcodes, product_id, kit_product_id|
      child_item = Hash.new

      child_item['name'] = name
      child_item['instruction'] = nil
      child_item['confirmation'] = false
      child_item['images'] = []
      child_item['sku'] = sku
      child_item['packing_placement'] = packing_placement
      child_item['barcodes'] = barcodes
      child_item['product_id'] = product_id
      child_item['skippable'] = false
      child_item['record_serial'] = false
      child_item['order_item_id'] = 0
      child_item['type_scan_enabled'] = 'on'
      child_item['click_scan_enabled'] = 'on'
      child_item['scanned_qty'] = scanned_qty
      child_item['qty_remaining'] = qty_remaining
      child_item['kit_packing_placement'] = kit_packing_placement
      child_item['kit_product_id'] = kit_product_id

      return child_item
    end

    @unscanned_item_l = lambda do |name, product_type, images, sku, qty_remaining,
      scanned_qty, packing_placement,
      barcodes, product_id, order_item_id, child_items,instruction,confirmation|

      unscanned_item = Hash.new

      unscanned_item["name"] = name
      unscanned_item['instruction'] = instruction
      unscanned_item['confirmation'] = confirmation
      unscanned_item["images"] = images
      unscanned_item["sku"] = sku
      unscanned_item["packing_placement"] = packing_placement
      unscanned_item["barcodes"] = barcodes
      unscanned_item["product_id"] = product_id
      unscanned_item['skippable'] = false
      unscanned_item['record_serial'] = false
      unscanned_item['type_scan_enabled'] = 'on'
      unscanned_item['click_scan_enabled'] = 'on'
      unscanned_item["order_item_id"] = order_item_id
      unscanned_item["product_type"] = product_type
      unscanned_item["qty_remaining"] = qty_remaining
      unscanned_item["scanned_qty"] = scanned_qty

      if !child_items.nil?
        unscanned_item['child_items'] = child_items
        child_items.each do |child_item|
          child_item['order_item_id'] = order_item_id
        end
      end

      return unscanned_item
    end

    @scanned_item_l = lambda do |name, product_type, images, sku, qty_remaining,
      scanned_qty, packing_placement,
      barcodes, product_id, order_item_id, child_items|
      scanned_item = Hash.new

      scanned_item["name"] = name
      scanned_item['instruction'] = nil
      scanned_item['confirmation'] = false
      scanned_item["images"] = images
      scanned_item["sku"] = sku
      scanned_item["packing_placement"] = packing_placement
      scanned_item["barcodes"] = barcodes
      scanned_item["product_id"] = product_id
      scanned_item['skippable'] = false
      scanned_item['record_serial'] = false
      scanned_item['type_scan_enabled'] = 'on'
      scanned_item['click_scan_enabled'] = 'on'
      scanned_item["order_item_id"] = order_item_id
      scanned_item["product_type"] = product_type
      scanned_item["qty_remaining"] = qty_remaining
      scanned_item["scanned_qty"] = scanned_qty

      if !child_items.nil?
        scanned_item['child_items'] = child_items
        child_items.each do |child_item|
          child_item['order_item_id'] = order_item_id
        end
      end

      return scanned_item
    end

    @expected_result_l = lambda do |order, kit_product_barcode|
      expected_result = Hash.new
      expected_result['status'] = true
      expected_result['error_messages'] = []
      expected_result['success_messages'] = []
      expected_result['notice_messages'] = []

      order.reload
      kit_product_barcode.reload
      expected_result['data'] = Hash.new
      expected_result['data']['next_state'] = 'scanpack.rfp.default'
      expected_result['data']['serial'] = Hash.new
      expected_result['data']['serial']['ask'] = false
      expected_result['data']['serial']['clicked'] = false
      expected_result['data']['serial']['barcode'] = kit_product_barcode.barcode
      expected_result['data']['serial']['order_id'] = order.id.to_s
      expected_result['data']['order_num'] = order.increment_id.to_s
      expected_result['data']['order'] = order.attributes
      expected_result['data']['order']['increment_id'] = order.increment_id.to_s
      expected_result['data']['order']['packing_user_id'] = @user.id
      expected_result['data']['order']['unscanned_items'] = []
      expected_result['data']['order']['scanned_items'] = []

      #expected_result['data']['most_recent_scanned_products'] = []

      #expected_result['data']['next_item_present'] = false

      return expected_result
    end

    @get_response_l = lambda do |response|
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
    end

    @hash_diff_l = lambda do |hash1, hash2|
      puts "Diffing the two hashes:"
     puts Hash[*(
        (hash2.size > hash1.size)    \
            ? hash2.to_a - hash1.to_a \
            : hash1.to_a - hash2.to_a
        ).flatten].to_s
    end

    @next_item_recommendation_l = lambda do |item|
      next_item = item
      next_item['qty'] = next_item['scanned_qty'] + next_item['qty_remaining']
     return next_item
    end

  end

  describe "Order Case Insensitive" do
    it "should find a barcode with case insensitive search single items" do
      request.accept = "application/json"
      inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      order = FactoryGirl.create(:order, :status=>'awaiting', store: store)

      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product, barcode: "ABCDEFGH")

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>3, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'abcdefgh', :id => order.id }
      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'abcdefgh', :id => order.id }
      get :scan_barcode, {:state=>'scanpack.rfp.default', :input => 'abcdefgh', :id => order.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)

      order.reload
      expect(order.status).to eq("awaiting")
      order_item.reload
      expect(order_item.scanned_qty).to eq(3)
      expect(order_item.scanned_status).to eq("scanned")
    end

    it "should find a barcode with case insensitive search for item within a kit" do
      request.accept = "application/json"
      inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
      order = FactoryGirl.create(:order, :status=>'awaiting', :store=>store)

      product = FactoryGirl.create(:product, :name=>'iPhone 5S', :packing_placement=>20)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode => 'BARCODE1')

      order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
                    :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>product.name)

      product_kit = FactoryGirl.create(:product, :is_kit => 1, :name=>'iPhone Protection Kit',
                        :kit_parsing=>'depends', :packing_placement=>30)
      product_kit_sku = FactoryGirl.create(:product_sku, :product=> product_kit, :sku=> 'IPROTO')
      product_kit_barcode = FactoryGirl.create(:product_barcode, :product=> product_kit, :barcode => 'IPROTOBAR')
      order_item_kit = FactoryGirl.create(:order_item, :product_id=>product_kit.id,
                    :qty=>2, :price=>"10", :row_total=>"10", :order=>order, :name=>product_kit.name)

      kit_product = FactoryGirl.create(:product, :name=>'Protection Sheet', :packing_placement=>30)
      kit_product_sku = FactoryGirl.create(:product_sku, :product=> kit_product, :sku=> 'IPROTO1')
      kit_product_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product, :barcode => 'KITITEM1')

      product_kit_sku = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product.id)
      order_item_kit_product = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,
            :product_kit_skus=> product_kit_sku)

      kit_product2 = FactoryGirl.create(:product, :name=>'Screen Wiper', :packing_placement=>40)
      kit_product2_sku = FactoryGirl.create(:product_sku, :product=> kit_product2, :sku=> 'IPROTO2')
      kit_product2_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product2, :barcode => 'KITITEM2')

      product_kit_sku2 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product2.id)
      order_item_kit_product2 = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,
            :product_kit_skus => product_kit_sku2)

      kit_product3 = FactoryGirl.create(:product, :name=>'Instruction Manual', :packing_placement=>50)
      kit_product3_sku = FactoryGirl.create(:product_sku, :product=> kit_product3, :sku=> 'IPROTO3')
      kit_product3_barcode = FactoryGirl.create(:product_barcode, :product=> kit_product3, :barcode => 'KITITEM3')

      product_kit_sku3 = FactoryGirl.create(:product_kit_sku, :product => product_kit, :option_product_id=>kit_product3.id)
      order_item_kit_product3 = FactoryGirl.create(:order_item_kit_product, :order_item => order_item_kit,
            :product_kit_skus => product_kit_sku3)

      order_item2 = FactoryGirl.create(:order_item, :product_id=>kit_product2.id,
              :qty=>1, :price=>"10", :row_total=>"10", :order=>order, :name=>kit_product2.name)


      get :scan_barcode, { :state =>'scanpack.rfp.default', :input => 'barcode1', :id => order.id }
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['data']['order']['unscanned_items'].length).to eq(2)
      expect(result['data']['order']['unscanned_items'].first['name']).to eq('iPhone Protection Kit')
      expect(result['data']['order']['unscanned_items'].first['child_items']).to eq(nil)
      expect(result['data']['next_state']).to eq('scanpack.rfp.default')
    end
  end
end

