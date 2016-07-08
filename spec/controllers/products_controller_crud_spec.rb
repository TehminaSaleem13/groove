require 'rails_helper'

RSpec.describe ProductsController, :type => :controller do
	before(:each) do
		sup_ad = FactoryGirl.create(:role,:name=>'super_admin1',:make_super_admin=>true)
		@user = FactoryGirl.create(:user,:username=>"new_admin1", :role=>sup_ad)
    # @user = FactoryGirl.create(:user, :username=>"Scan & Pack User")
    sign_in @user

    Delayed::Worker.delay_jobs = false
  end


  describe 'Product' do

    context 'attributes' do
      it 'allows reading and writing for :name' do
       product = Product.new
       product.name = 'Test Product'
       expect(product.name).to eq('Test Product')
     end

     it 'allows reading and writing for :store_product_id' do
       product = Product.new
       product.store_product_id = 'Test store product id'
       expect(product.store_product_id).to eq('Test store product id')
     end
   end

   before(:each) do
     request.accept = "application/json"
     inv_wh = FactoryGirl.create(:inventory_warehouse,:is_default => true)
     store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)

     @product = FactoryGirl.create(:product, :name=>'Apple iPhone 5C')
     product_sku = FactoryGirl.create(:product_sku, :product=> @product, :sku=>'IPHONE5C')
     product_barcode = FactoryGirl.create(:product_barcode, :product=> @product, :barcode=>'1234567891')

     @p_alias = FactoryGirl.create(:product, :name=>'Apple iPhone 5S')
     p_alias_sku = FactoryGirl.create(:product_sku, :product=> @p_alias, :sku=>'IPHONE5S')
     p_alias_barcode = FactoryGirl.create(:product_barcode, :product=> @p_alias, :barcode=>'1234567892')
   end

   context 'add product to kit' do
    it 'Should add product to kit' do
     post :add_product_to_kit, {:id=>@product.id, :product_ids=>[@p_alias.id], :product=>{}}
     expect(response.status).to eq(200)
     result = JSON.parse(response.body)
   end

   it 'Should return message whilie passing nil value of product to kit' do
     product_id_kit = nil
     message = ["No item sent in the request"]

     post :add_product_to_kit, {:id=>@product.id, :product_ids=>product_id_kit, :product=>{}}
     expect(response.status).to eq(200)
     result = JSON.parse(response.body)
     expect(result['messages']).to eq(message)
   end
 end

 context 'remove product from kit' do
  it 'Should remove product from kit' do
    post :add_product_to_kit, {:id=>@product.id, :product_ids=>[@p_alias.id], :product=>{}}
    expect(response.status).to eq(200)
    result = JSON.parse(response.body)

    post :remove_products_from_kit, {:id=>@product.id, :kit_products=>[@p_alias.id], :product=>{}}
    expect(response.status).to eq(200)
    result = JSON.parse(response.body)
  end

  it 'Should return failure message whilie passing nil value of product' do
   message = ["No sku sent in the request"]
       # passing "@product_id_kit" variable which contains nothing
       post :remove_products_from_kit, {:id=>@product.id, :kit_products=>@product_id_kit, :product=>{}}
       expect(response.status).to eq(200)
       result = JSON.parse(response.body)
       expect(result['messages']).to eq(message)
     end

     it 'Should return failure message whilie passing wrong value of product' do
      message = ["Product #{@p_alias.id} not found in item"]

      post :remove_products_from_kit, {:id=>@product.id, :kit_products=>[@p_alias.id], :product=>{}}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result['messages']).to eq(message)
    end

  end

  context 'set_alias' do
    it 'Should make alias of another product' do
     post :set_alias, {:id=>@product.id, :product_alias_ids=>[@p_alias.id], :product=>{}}
     expect(response.status).to eq(200)
     result = JSON.parse(response.body)
   end

   it 'Should show message if fails to make alias' do
     message = ["No products found to alias"]

     post :set_alias, {:id=>@product.id, :product_alias_ids=>[123], :product=>{}}
     expect(response.status).to eq(200)
     result = JSON.parse(response.body)
     expect(result["messages"]).to eq(message)
   end

 end

 context 'update intangibleness' do
  it 'Should update intangibleness to false' do
    scan_pack_setting = ScanPackSetting.create
    intengible_option = false
    status = true

    post :update_intangibleness, {:ask_tracking_number=>true, :enable_click_sku=>true, :escape_string=>" - ", :escape_string_enabled=>true, :fail_image_src=>"/assets/images/scan_fail.png", :fail_image_time=>1, :fail_sound_url=>"/assets/sounds/scan_fail.mp3", :fail_sound_vol=>0.75, :id=>scan_pack_setting.id, :intangible_setting_enabled=>intengible_option, :intangible_setting_gen_barcode_from_sku=>false, :intangible_string=>"R.INTANGIBLE.SEA", :note_from_packer_code=>"NOTE", :note_from_packer_code_enabled=>true, :order_complete_image_src=>"/assets/images/scan_order_complete.png", :order_complete_image_time=>1, :order_complete_sound_url=>"/assets/sounds/scan_order_complete.mp3", :order_complete_sound_vol=>0.75, :play_fail_sound=>true, :play_order_complete_sound=>true, :play_success_sound=>true, :post_scan_pause_enabled=>false, :post_scan_pause_time=>4, :post_scanning_option=>"None", :record_lot_number=>true, :restart_code=>"RESTART", :restart_code_enabled=>true, :scan_by_tracking_number=>false, :service_issue_code=>"ISSUE", :service_issue_code_enabled=>true, :show_customer_notes=>false, :show_fail_image=>true, :show_internal_notes=>false, :show_order_complete_image=>true, :show_success_image=>true, :skip_code=>"SKIP", :skip_code_enabled=>true, :success_image_src=>"/assets/images/scan_success.png", :success_image_time=>0.5, :success_sound_url=>"/assets/sounds/scan_success.mp3", :success_sound_vol=>0.75, :type_scan_code=>"*", :type_scan_code_enabled=>true}
    expect(response.status).to eq(200)
    result = JSON.parse(response.body)
    expect(result['status']).to eq(status)
  end  

  it 'Should update intangibleness to true' do
    scan_pack_setting = ScanPackSetting.create
    intengible_option = true
    status = true

    post :update_intangibleness, {:ask_tracking_number=>true, :enable_click_sku=>true, :escape_string=>" - ", :escape_string_enabled=>true, :fail_image_src=>"/assets/images/scan_fail.png", :fail_image_time=>1, :fail_sound_url=>"/assets/sounds/scan_fail.mp3", :fail_sound_vol=>0.75, :id=>scan_pack_setting.id, :intangible_setting_enabled=>intengible_option, :intangible_setting_gen_barcode_from_sku=>false, :intangible_string=>"R.INTANGIBLE.SEA", :note_from_packer_code=>"NOTE", :note_from_packer_code_enabled=>true, :order_complete_image_src=>"/assets/images/scan_order_complete.png", :order_complete_image_time=>1, :order_complete_sound_url=>"/assets/sounds/scan_order_complete.mp3", :order_complete_sound_vol=>0.75, :play_fail_sound=>true, :play_order_complete_sound=>true, :play_success_sound=>true, :post_scan_pause_enabled=>false, :post_scan_pause_time=>4, :post_scanning_option=>"None", :record_lot_number=>true, :restart_code=>"RESTART", :restart_code_enabled=>true, :scan_by_tracking_number=>false, :service_issue_code=>"ISSUE", :service_issue_code_enabled=>true, :show_customer_notes=>false, :show_fail_image=>true, :show_internal_notes=>false, :show_order_complete_image=>true, :show_success_image=>true, :skip_code=>"SKIP", :skip_code_enabled=>true, :success_image_src=>"/assets/images/scan_success.png", :success_image_time=>0.5, :success_sound_url=>"/assets/sounds/scan_success.mp3", :success_sound_vol=>0.75, :type_scan_code=>"*", :type_scan_code_enabled=>true}
    expect(response.status).to eq(200)
    result = JSON.parse(response.body)
    expect(result['status']).to eq(status)
  end 
end

context 'search' do
  it 'Should return searched item' do
    status = true

    get :search, {:search=>@p_alias.id, :limit=>"20", :offset=>"0"}
    expect(response.status).to eq(200)
    result = JSON.parse(response.body)
    expect(result['status']).to eq(status)
  end

  it 'Should return error message for improper search' do
    request.accept = "application/json"
    improper_search_message = 'Improper search string'
    get :search, {:search=>"", :limit=>"20", :offset=>"0"}
    expect(response.status).to eq(200)
    result = JSON.parse(response.body)
    expect(result["message"]).to eq(improper_search_message)
  end
end

end

describe 'Product' do
 context 'attributes' do
  it 'allows reading and writing for :name' do
   product = Product.new
   product.name = 'Test Product'
   expect(product.name).to eq('Test Product')
 end

 it 'allows reading and writing for :store_product_id' do
   product = Product.new
   product.store_product_id = 'Test store product id'
   expect(product.store_product_id).to eq('Test store product id')
 end
end

it 'Should get all products' do
  request.accept = "application/json"
  inv_wh = FactoryGirl.create(:inventory_warehouse,:is_default => true)
  store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)

  product = FactoryGirl.create(:product, :name=>'Apple iPhone 5C')
  product_sku = FactoryGirl.create(:product_sku, :product=> product, :sku=>'IPHONE5C')
  product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode=>'1234567891')

  product.save!

  products = Product.all
  get :index, {}
  expect(response.status).to eq(200)
  result = JSON.parse(response.body)

end

it 'Should create new product' do
  request.accept = "application/json"
  inv_wh = FactoryGirl.create(:inventory_warehouse,:is_default => true)
  store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)

  post :create, {:id=>store.id, :name=> 'New Product', :status=>'1', :store_type=>'system', :inventory_warehouse_id=>'1' }
  store.reload    
  expect(response.status).to eq(200)
  result = JSON.parse(response.body)
end

it 'Should add image to product' do
  request.accept = "application/json"
  inv_wh = FactoryGirl.create(:inventory_warehouse,:is_default => true)
  store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)

  product = FactoryGirl.create(:product, :name=>'Apple iPhone 5C')
  product_sku = FactoryGirl.create(:product_sku, :product=> product, :sku=>'IPHONE5C')
  product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode=>'1234567891')

  product.save!

  @file = fixture_file_upload('/files/test_image.png', 'png')

  post :add_image, {:id=>product.id, :product_image=>@file}
  expect(response.status).to eq(200)
  result = JSON.parse(response.body)
end

it 'Should update image for product' do
  request.accept = "application/json"

  inv_wh = FactoryGirl.create(:inventory_warehouse,:is_default => true)
  store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)

  product = FactoryGirl.create(:product, :name=>'Apple iPhone 5C')
  product_sku = FactoryGirl.create(:product_sku, :product=> product, :sku=>'IPHONE5C')
  product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode=>'1234567891')

  product.save!

  @file = fixture_file_upload('/files/test_image.png', 'png')

  post :add_image, {:id=>product.id, :product_image=>@file}
  expect(response.status).to eq(200)
  result = JSON.parse(response.body)

  @file_1 = fixture_file_upload('/files/Groovepacker_image.png', 'png')
  image_id = ProductImage.all.first.id

  post :add_image, {:id=>product.id, :product_image=>@file_1}
  expect(response.status).to eq(200)
  result_1 = JSON.parse(response.body)

  @update_file = {
    "added_to_receiving_instructions"=>false, 
    "caption"=>nil,
    "id"=>product.id, 
    "image"=>@file_1,
    "image_note"=>" Note for image",
    "order"=>0,
    "product_id"=>product.id,
    "checked"=>true
  }

  post :update_image, {:id=>product.id, :image=>@update_file}
  expect(response.status).to eq(200)
  result = JSON.parse(response.body)
end

it 'Should sync with product' do
  request.accept = "application/json"
  inv_wh = FactoryGirl.create(:inventory_warehouse,:is_default => true)
  store = FactoryGirl.create(:store, :inventory_warehouse_id => inv_wh.id)

  product = FactoryGirl.create(:product, :name=>'Apple iPhone 5C')
  product_sku = FactoryGirl.create(:product_sku, :product=> product, :sku=>'IPHONE5C')
  product_barcode = FactoryGirl.create(:product_barcode, :product=> product, :barcode=>'1234567891')

  product.save!

  post :sync_with, {:id=>product.id, :sync_with_bc=>nil, :bc_product_id=>nil, :bc_product_sku=>nil, :sync_with_mg_rest=>nil, :mg_rest_product_id=>nil, :sync_with_shopify=>nil, :shopify_product_variant_id=>nil, :mg_rest_product_sku=>nil, :sync_with_teapplix=>true, :teapplix_product_sku=>nil}
  expect(response.status).to eq(200)
  result = JSON.parse(response.body)
end

end

end
