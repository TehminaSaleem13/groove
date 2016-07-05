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

  	context 'change product status' do
  		it 'Should change status of product to inactive' do
  			products_status_update = [{:id=>@product.id}, {:id=>@p_alias.id}]
  			post :change_product_status, {:productArray=>products_status_update, :activity=>'status_update', :status=>"inactive"}
  			expect(response.status).to eq(200)
  			result = JSON.parse(response.body)
  		end

  		it 'Should change status of product to active' do
  			products_status_update = [{:id=>@product.id}, {:id=>@p_alias.id}]
  			post :change_product_status, {:productArray=>products_status_update, :activity=>'status_update', :status=>"active"}
  			expect(response.status).to eq(200)
  			result = JSON.parse(response.body)
  		end

  		it 'Should change status of product to new' do
  			products_status_update = [{:id=>@product.id}, {:id=>@p_alias.id}]
  			post :change_product_status, {:productArray=>products_status_update, :activity=>'status_update', :status=>"new"}
  			expect(response.status).to eq(200)
  			result = JSON.parse(response.body)
  		end
  	end

  	context 'delete product' do
  		it 'Should delete product from products list' do
  			products_delete = [{:id=>@product.id}, {:id=>@p_alias.id}]
  			post :delete_product, {:productArray=>products_delete, :activity=>'delete'}
  			expect(response.status).to eq(200)
  			result = JSON.parse(response.body)
  		end
  	end

  	context 'duplicate product' do
  		it 'Should create a  product' do
  			products_list = [{:id=>@product.id}, {:id=>@p_alias.id}]
  			post :duplicate_product, {:productArray=>products_list, :activity=>'duplicate'}
  			expect(response.status).to eq(200)
  			result = JSON.parse(response.body)
  		end
  	end


  end
end
