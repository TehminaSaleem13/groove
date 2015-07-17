require 'rails_helper'
#include Devise::TestHelpers

describe ScanPackController do
	before(:each) do
    SeedTenant.new.seed
    scanpacksetting = ScanPackSetting.first
    scanpacksetting.post_scanning_option = "None"
    scanpacksetting.record_lot_number = true
    scanpacksetting.escape_string_enabled = true
    scanpacksetting.escape_string = ' - '
    scanpacksetting.save
    general_setting = GeneralSetting.all.first
    general_setting.inventory_tracking = true
    general_setting.save

    @user = FactoryGirl.create(:user, :username=>"scan_pack_spec_user", :name=>'Scan Pack user', 
      :role => Role.find_by_name('Scan & Pack User'))

    request.env["devise.mapping"] = Devise.mappings[:user]
    sign_in :user, @user 
  end
  describe "Order Scan" do
		it "stores lot_number if it is provided along with the barcode while scanning the item" do
			request.accept = "application/json"
			inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
			# product_lot = FactoryGirl.create(:product_lot)
	    order = FactoryGirl.create(:order, :status=>'awaiting', :store=>store)
	    product = FactoryGirl.create(:product)
	    product_sku = FactoryGirl.create(:product_sku, :product=> product)
	    product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode=>'1236547890')
	    order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
	                  :qty=>1, :order=>order, :name=>product.name)

	    product2 = FactoryGirl.create(:product, :name=>"Apple iPhone5C")
	    product_sku2 = FactoryGirl.create(:product_sku, :product=> product2, :sku=>'iPhone5C')
	    product_barcode2 = FactoryGirl.create(:product_barcode, :product=> product2, :barcode=>"12456789")
	    order_item2 = FactoryGirl.create(:order_item, :product_id=>product2.id,
	                  :qty=>1, :order=>order, :name=>product2.name)

	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '1236547890 - LOT1', :id => order.id }
	    expect(response.status).to eq(200)
	    product_lots = ProductLot.where(product_id: product.id)
	    expect(product_lots.first.lot_number).to eq('LOT1')

	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '12456789 - LOT2', :id => order.id }
	    expect(response.status).to eq(200)
	    product_lots = ProductLot.where(product_id: product2.id)
	    expect(product_lots.first.lot_number).to eq('LOT2')
		end

		it "stores order_serial if record_serial is enabled for the product" do
			request.accept = "application/json"
			inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
			order_serial = FactoryGirl.create(:order_serial)
	    order = FactoryGirl.create(:order, :status=>'awaiting', :store=>store)
	    product = FactoryGirl.create(:product)
	    product_sku = FactoryGirl.create(:product_sku, :product=> product)
	    product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode=>'1236547890')
	    order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
	                  :qty=>1, :order=>order, :name=>product.name)
	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '1236547890', :id => order.id }
	    expect(response.status).to eq(200)
	    data=extract_response(response)
	    get :serial_scan, {:order_id=>order.id, :product_id => product.id, :serial => 'product1serial', :product_lot_id => data["product_lot_id"], :barcode => data["barcode"], :order_item_id => data["order_item_id"] }
	    expect(response.status).to eq(200)
	    order_serials = order.order_serials
	    expect(order_serials.first.serial).to eq('product1serial')
		end

		it "increases the qty for the lot_number when the same lot and same order serial are provided for the same order item" do
			request.accept = "application/json"
			inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
			product_lot = FactoryGirl.create(:product_lot)
			# order_item_serial_lot = FactoryGirl.create(:order_item_order_serial_product_lot)
	    order = FactoryGirl.create(:order, :status=>'awaiting', :store=>store)
	    product = FactoryGirl.create(:product, :record_serial=>true)
	    product_sku = FactoryGirl.create(:product_sku, :product=> product)
	    product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode=>'1236547890')
	    order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
	                  :qty=>2, :order=>order, :name=>product.name)

	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '1236547890 - LOT1', :id => order.id }
	    expect(response.status).to eq(200)
	    data=extract_response(response)
	    get :serial_scan, {:order_id=>order.id, :product_id => product.id, :serial => 'productserial1', :product_lot_id => data["product_lot_id"], :barcode => data["barcode"], :order_item_id => data["order_item_id"] }
	    expect(response.status).to eq(200)
	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '1236547890 - LOT1', :id => order.id }
	    expect(response.status).to eq(200)
	    data=extract_response(response)
	    get :serial_scan, {:order_id=>order.id, :product_id => product.id, :serial => 'productserial1', :product_lot_id => data["product_lot_id"], :barcode => data["barcode"], :order_item_id => data["order_item_id"] }
	    expect(response.status).to eq(200)

	    expect(OrderItemOrderSerialProductLot.first.qty).to eq(2)
		end

		it "creates different records in OrderItemOrderSerialProductLot if lot_number and order_serials are different" do
			request.accept = "application/json"
			inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
			product_lot = FactoryGirl.create(:product_lot)
			# order_item_serial_lot = FactoryGirl.create(:order_item_order_serial_product_lot)
	    order = FactoryGirl.create(:order, :status=>'awaiting', :store=>store)
	    product = FactoryGirl.create(:product, :record_serial=>true)
	    product_sku = FactoryGirl.create(:product_sku, :product=> product)
	    product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode=>'1236547890')
	    order_item = FactoryGirl.create(:order_item, :product_id=>product.id,
	                  :qty=>4, :order=>order, :name=>product.name)

	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '1236547890 - LOT1', :id => order.id }
	    expect(response.status).to eq(200)
	    data=extract_response(response)
	    get :serial_scan, {:order_id=>order.id, :product_id => product.id, :serial => 'productserial1', :product_lot_id => data["product_lot_id"], :barcode => data["barcode"], :order_item_id => data["order_item_id"] }
	    expect(response.status).to eq(200)
	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '1236547890 - LOT1', :id => order.id }
	    expect(response.status).to eq(200)
	    data=extract_response(response)
	    get :serial_scan, {:order_id=>order.id, :product_id => product.id, :serial => 'productserial1', :product_lot_id => data["product_lot_id"], :barcode => data["barcode"], :order_item_id => data["order_item_id"] }
	    expect(response.status).to eq(200)
	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '1236547890 - LOT2', :id => order.id }
	    expect(response.status).to eq(200)
	    data=extract_response(response)
	    get :serial_scan, {:order_id=>order.id, :product_id => product.id, :serial => 'productserial1', :product_lot_id => data["product_lot_id"], :barcode => data["barcode"], :order_item_id => data["order_item_id"] }
	    expect(response.status).to eq(200)
	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '1236547890 - LOT1', :id => order.id }
	    expect(response.status).to eq(200)
	    data=extract_response(response)
	    get :serial_scan, {:order_id=>order.id, :product_id => product.id, :serial => 'productserial2', :product_lot_id => data["product_lot_id"], :barcode => data["barcode"], :order_item_id => data["order_item_id"] }
	    expect(response.status).to eq(200)

	    order_item_serial_lots = OrderItemOrderSerialProductLot.all
	    expect(order_item_serial_lots.first.qty).to eq(2)
	    expect(order_item_serial_lots[1].qty).to eq(1)
	    expect(order_item_serial_lots.last.qty).to eq(1)
		end

		it "scanning an add_to_any_order enabled item during an order scan adds the item to the order item list of the order" do
			request.accept = "application/json"
			inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
	    order = FactoryGirl.create(:order, :status=>'awaiting', :store=>store)

	    product1 = FactoryGirl.create(:product)
	    product_inv_wh1 = FactoryGirl.create(:product_inventory_warehouse, :product=> product1,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)
	    product_sku1 = FactoryGirl.create(:product_sku, :product=> product1)
	    product_barcode1 = FactoryGirl.create(:product_barcode, :product=> product1, :barcode=>'1236547890')
	    order_item1 = FactoryGirl.create(:order_item, :product_id=>product1.id,
	                  :qty=>4, :order=>order, :name=>product1.name)

	    product2 = FactoryGirl.create(:product)
	    product_inv_wh2 = FactoryGirl.create(:product_inventory_warehouse, :product=> product2,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)
	    product_sku2 = FactoryGirl.create(:product_sku, :product=> product2, :sku=>"IPHONE5C")
	    product_barcode2 = FactoryGirl.create(:product_barcode, :product=> product2, :barcode=>'2236547890')
	    order_item2 = FactoryGirl.create(:order_item, :product_id=>product2.id,
	                  :qty=>4, :order=>order, :name=>product2.name)

	    product3 = FactoryGirl.create(:product, :add_to_any_order=>true)
	    product_inv_wh3 = FactoryGirl.create(:product_inventory_warehouse, :product=> product3,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)
	    product_sku3 = FactoryGirl.create(:product_sku, :product=> product3, :sku=>"IPHONE5Z")
	    product_barcode3 = FactoryGirl.create(:product_barcode, :product=> product3, :barcode=>'3236547890')

	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '1236547890', :id => order.id }
	    expect(response.status).to eq(200)	    
	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '2236547890', :id => order.id }
	    expect(response.status).to eq(200)
	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '3236547890', :id => order.id }
	    expect(response.status).to eq(200)
	    order.reload()
	    expect(order.order_items).to include(product3.order_items.first)
		end

		it "scanning an add_to_any_order enabled item multiple times during an order scan adds the item to the order item list of the order and increases qty" do
			request.accept = "application/json"
			inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
	    order = FactoryGirl.create(:order, :status=>'awaiting', :store=>store)

	    product1 = FactoryGirl.create(:product)
	    product_inv_wh1 = FactoryGirl.create(:product_inventory_warehouse, :product=> product1,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)
	    product_sku1 = FactoryGirl.create(:product_sku, :product=> product1)
	    product_barcode1 = FactoryGirl.create(:product_barcode, :product=> product1, :barcode=>'1236547890')
	    order_item1 = FactoryGirl.create(:order_item, :product_id=>product1.id,
	                  :qty=>4, :order=>order, :name=>product1.name)

	    product2 = FactoryGirl.create(:product)
	    product_inv_wh2 = FactoryGirl.create(:product_inventory_warehouse, :product=> product2,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)
	    product_sku2 = FactoryGirl.create(:product_sku, :product=> product2, :sku=>"IPHONE5C")
	    product_barcode2 = FactoryGirl.create(:product_barcode, :product=> product2, :barcode=>'2236547890')
	    order_item2 = FactoryGirl.create(:order_item, :product_id=>product2.id,
	                  :qty=>4, :order=>order, :name=>product2.name)

	    product3 = FactoryGirl.create(:product, :add_to_any_order=>true)
	    product_inv_wh3 = FactoryGirl.create(:product_inventory_warehouse, :product=> product3,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)
	    product_sku3 = FactoryGirl.create(:product_sku, :product=> product3, :sku=>"IPHONE5Z")
	    product_barcode3 = FactoryGirl.create(:product_barcode, :product=> product3, :barcode=>'3236547890')

	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '1236547890', :id => order.id }
	    expect(response.status).to eq(200)	    
	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '2236547890', :id => order.id }
	    expect(response.status).to eq(200)
	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '3236547890', :id => order.id }
	    expect(response.status).to eq(200)
	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '3236547890', :id => order.id }
	    expect(response.status).to eq(200)
	    order.reload()
	    order.order_items.reload()
	    expect(order.order_items).to include(product3.order_items.first)
	    expect(order.order_items.where(sku: "IPHONE5Z").first.qty).to eq(2)
		end

		it "stores lot_number for the add_to_any_order enabled item" do
			request.accept = "application/json"
			inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
	    order = FactoryGirl.create(:order, :status=>'awaiting', :store=>store)

	    product1 = FactoryGirl.create(:product)
	    product_inv_wh1 = FactoryGirl.create(:product_inventory_warehouse, :product=> product1,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)
	    product_sku1 = FactoryGirl.create(:product_sku, :product=> product1)
	    product_barcode1 = FactoryGirl.create(:product_barcode, :product=> product1, :barcode=>'1236547890')
	    order_item1 = FactoryGirl.create(:order_item, :product_id=>product1.id,
	                  :qty=>4, :order=>order, :name=>product1.name)

	    product2 = FactoryGirl.create(:product, :add_to_any_order=>true)
	    product_inv_wh2 = FactoryGirl.create(:product_inventory_warehouse, :product=> product2,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)
	    product_sku2 = FactoryGirl.create(:product_sku, :product=> product2, :sku=>"IPHONE5Z")
	    product_barcode2 = FactoryGirl.create(:product_barcode, :product=> product2, :barcode=>'3236547890')

	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '1236547890', :id => order.id }
	    expect(response.status).to eq(200)
	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '3236547890 - LOT1', :id => order.id }
	    expect(response.status).to eq(200)
	    product_lots = ProductLot.where(product_id: product2.id)
	    expect(product_lots.first.lot_number).to eq('LOT1')
		end

		it "stores serial_number for the add_to_any_order enabled item" do
			request.accept = "application/json"
			inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
	    order = FactoryGirl.create(:order, :status=>'awaiting', :store=>store)

	    product1 = FactoryGirl.create(:product)
	    product_inv_wh1 = FactoryGirl.create(:product_inventory_warehouse, :product=> product1,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)
	    product_sku1 = FactoryGirl.create(:product_sku, :product=> product1)
	    product_barcode1 = FactoryGirl.create(:product_barcode, :product=> product1, :barcode=>'1236547890')
	    order_item1 = FactoryGirl.create(:order_item, :product_id=>product1.id,
	                  :qty=>4, :order=>order, :name=>product1.name)

	    product2 = FactoryGirl.create(:product, :add_to_any_order=>true, :record_serial=>true)
	    product_inv_wh2 = FactoryGirl.create(:product_inventory_warehouse, :product=> product2,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)
	    product_sku2 = FactoryGirl.create(:product_sku, :product=> product2, :sku=>"IPHONE5Z")
	    product_barcode2 = FactoryGirl.create(:product_barcode, :product=> product2, :barcode=>'3236547890')

	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '1236547890', :id => order.id }
	    expect(response.status).to eq(200)
	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '3236547890 - LOT1', :id => order.id }
	    expect(response.status).to eq(200)
	    data=extract_response(response)
	    get :serial_scan, {:order_id=>order.id, :product_id => product2.id, :serial => 'productserial1', :product_lot_id => data["product_lot_id"], :barcode => data["barcode"], :order_item_id => data["order_item_id"] }
	    expect(response.status).to eq(200)

	    order_item_serial_lot = OrderItemOrderSerialProductLot.first
	    product_lots = ProductLot.where(product_id: product2.id)
	    expect(product_lots.first.lot_number).to eq('LOT1')
	    expect(order_item_serial_lot.product_lot.lot_number).to eq('LOT1')
	    expect(order_item_serial_lot.order_serial.serial).to eq('productserial1')
		end

		it "updates inventory for the add_to_any_order enabled item scanned during order scan" do
			request.accept = "application/json"
			inv_wh = FactoryGirl.create(:inventory_warehouse)

      store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)
	    order = FactoryGirl.create(:order, :status=>'awaiting', :store=>store)

	    product1 = FactoryGirl.create(:product)
	    product_inv_wh1 = FactoryGirl.create(:product_inventory_warehouse, :product=> product1,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)
	    product_sku1 = FactoryGirl.create(:product_sku, :product=> product1)
	    product_barcode1 = FactoryGirl.create(:product_barcode, :product=> product1, :barcode=>'1236547890')
	    order_item1 = FactoryGirl.create(:order_item, :product_id=>product1.id,
	                  :qty=>4, :order=>order, :name=>product1.name)

	    product2 = FactoryGirl.create(:product, :add_to_any_order=>true, :name=>"Apple iPhone 5Z")
	    product_inv_wh2 = FactoryGirl.create(:product_inventory_warehouse, :product=> product2,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)
	    product_sku2 = FactoryGirl.create(:product_sku, :product=> product2, :sku=>"IPHONE5Z")
	    product_barcode2 = FactoryGirl.create(:product_barcode, :product=> product2, :barcode=>'3236547890')

	    product3 = FactoryGirl.create(:product, :add_to_any_order=>true, :name=>"Apple iPhone 5T", :record_serial=>true)
	    product_inv_wh3 = FactoryGirl.create(:product_inventory_warehouse, :product=> product3,
                   :inventory_warehouse_id =>inv_wh.id, :available_inv => 25)
	    product_sku3 = FactoryGirl.create(:product_sku, :product=> product3, :sku=>"IPHONE5T")
	    product_barcode3 = FactoryGirl.create(:product_barcode, :product=> product3, :barcode=>'4236547890')

	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '1236547890', :id => order.id }
	    expect(response.status).to eq(200)
	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '3236547890 - LOT1', :id => order.id }
	    expect(response.status).to eq(200)
	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '3236547890 - LOT1', :id => order.id }
	    expect(response.status).to eq(200)
	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '4236547890 - LOT2', :id => order.id }
	    expect(response.status).to eq(200)
	    data=extract_response(response)
	    get :serial_scan, {:order_id=>order.id, :product_id => product3.id, :serial => 'productserial1', :product_lot_id => data["product_lot_id"], :barcode => data["barcode"], :order_item_id => data["order_item_id"] }
	    expect(response.status).to eq(200)
	    get :scan_barcode, {:state=>'scanpack.rfp.default', :input => '4236547890 - LOT2', :id => order.id }
	    expect(response.status).to eq(200)
	    data=extract_response(response)
	    get :serial_scan, {:order_id=>order.id, :product_id => product3.id, :serial => 'productserial2', :product_lot_id => data["product_lot_id"], :barcode => data["barcode"], :order_item_id => data["order_item_id"] }
	    expect(response.status).to eq(200)

	    product_inv_wh1.reload()
	    product_inv_wh2.reload()
	    product_inv_wh3.reload()

	    expect(product_inv_wh1.available_inv).to eq(21)
	    expect(product_inv_wh2.available_inv).to eq(23)
	    expect(product_inv_wh3.available_inv).to eq(23)
		end

		def extract_response(response)
			result = JSON.parse(response.body)
			data = Hash.new
	    data["product_lot_id"] = result["data"]["serial"]["product_lot_id"]
	    data["barcode"] = result["data"]["serial"]["barcode"]
	    data["order_item_id"] = result["data"]["serial"]["order_item_id"]
	    data
		end
	end
end
