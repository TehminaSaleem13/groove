require 'eBayAPI'
require 'rails_helper'

RSpec.describe ProductsHelper, type: :helper do
  before(:each) do
    @inv_wh = FactoryGirl.create(
      :inventory_warehouse, name: 'amazon_inventory_warehouse',
      is_default: true
    )
    @store = FactoryGirl.create(
      :store, name: 'amazon_store', inventory_warehouse: @inv_wh
    )
  end

  def random_string
    "#{5.times.reduce(''){|str, t| str += (65 + rand(25)).chr}}"
  end

  context 'Update Product with Amazon Product Details' do
    before(:each) do
      @amazon_credentials = FactoryGirl.create(
        :amazon_credential, store_id: @store.id,
        import_images: true, import_products: true
      )
    end

    it 'updates the product' do
      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, product: product)
      product_barcode = FactoryGirl.create(:product_barcode, product: product)
      product_inv_wh = FactoryGirl.create(:product_inventory_warehouse, product: product,
                   inventory_warehouse_id: @inv_wh.id, available_inv: 25)
      amazon_produt_details = {
        'GetMatchingProductForIdResult' => {
          'Products' => {
            'Product' => {
              'AttributeSets' => {
                'ItemAttributes' => {
                  'Title' => 'Testing',
                  'ItemDimensions' => {'Weight' => 1},
                  'PackageDimensions' => {'Weight' => 1},
                  'SmallImage' => {'URL' => 'test_url'},
                  'ProductGroup' => 'test_cat'
                }
              },
              'Identifiers' => {
                'MarketplaceASIN' => {'ASIN' => 'SPID'}
              }
            }
          }
        }
      }

      # If valid Data
      allow_any_instance_of(ProductsService::AmazonImport).to receive(:product_hash).and_return(amazon_produt_details)
      result = helper.import_amazon_product_details(@store.id, product_sku.sku, product.id)
      expect(result).to eq true

      # If amazon_credential not found with store id
      @amazon_credentials.update_attribute(:store_id, nil)
      result = helper.import_amazon_product_details(@store.id, product_sku.sku, product.id)
      expect(result).to eq false
    end
  end

  context 'Update Product List' do
    it 'Updates Editable products from product list' do
      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, product: product)
      product_barcode = FactoryGirl.create(:product_barcode, product: product)
      product_inv_wh = FactoryGirl.create(:product_inventory_warehouse, product: product,
                   inventory_warehouse_id: @inv_wh.id, available_inv: 25)

      editables = {
        name: 'test', status: 'inactive', is_skippable: true,
        type_scan_enabled: '1', click_scan_enabled: '1',
        spl_instructions_4_packer: 'Testing', sku: 'Test',
        category: '1', barcode: 'BAR'
      }

      editables.each do |k, v|
        helper.updatelist(product, k.to_s, v)
        result = product.reload[k.to_s] || product.send("primary_#{k.to_s}")
        expect(result).to eq v
      end

      # if location params
      location = {
        location_primary: 'Test', location_secondary: 'Test',
        location_tertiary: 'Test'
      }

      location.each do |k, v|
        helper.updatelist(product, k.to_s, v)
        result = product.primary_warehouse[k.to_s]
        expect(result).to eq v
      end

      helper.updatelist(product, 'location_name', 'test')
      expect(product.primary_warehouse.name).to eq 'test'

      product.primary_warehouse.destroy
      helper.updatelist(product.reload, 'qty_on_hand', 124)
      expect(product.primary_warehouse.quantity_on_hand).to eq 124
    end
  end

  context 'Ebay Import' do
    it 'Imports product detail from ebay' do
      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, product: product)
      product_barcode = FactoryGirl.create(:product_barcode, product: product)
      product_inv_wh = FactoryGirl.create(
        :product_inventory_warehouse, product: product,
        inventory_warehouse_id: @inv_wh.id, available_inv: 25
      )
      @ebay_credentials = FactoryGirl.create(
        :ebay_credential, store_id: @store.id, productauth_token: 'test',
        import_images: true, import_products: true
      )

      @ebay = EBay::API.new(@ebay_credentials.productauth_token,
                            ENV['EBAY_DEV_ID'], ENV['EBAY_APP_ID'],
                            ENV['EBAY_CERT_ID'])
      class Item
        def initialize(hash)
          hash.each do |k, v|
            instance_variable_set("@#{k}", v)
            singleton_class.class_eval { attr_accessor "#{k}" }
          end
        end

        def shippingDetails
        end

        def pictureDetails
        end

        def primaryCategory
          'pC'
        end

        def secondaryCategory
          'sC'
        end
      end
      ebay_dummy_return_object = {
        title: 'any', itemID: 'ABCD', sKU: 'SKU'
      }
      item = Item.new(ebay_dummy_return_object)

      allow_any_instance_of(ProductsService::EbayImport).to receive(:item_from_ebay).and_return(item)
      allow_any_instance_of(Item).to receive_message_chain(
        "shippingDetails.calculatedShippingRate.weightMajor"
      ).and_return(10)
      allow_any_instance_of(Item).to receive_message_chain(
        "shippingDetails.calculatedShippingRate.weightMinor"
      ).and_return(5)
      allow_any_instance_of(Item).to receive_message_chain(
        "pictureDetails.pictureURL.first.request_uri"
      ).and_return('image')
      allow_any_instance_of(Item).to receive_message_chain(
        "primaryCategory.categoryName"
      ).and_return('CN1')
      allow_any_instance_of(Item).to receive_message_chain(
        "secondaryCategory.categoryName"
      ).and_return('CN2')

      result = helper.import_ebay_product('ABCD', product_sku.sku, @ebay, @ebay_credentials)
      expect(result).to eq product.id

      result = helper.import_ebay_product('ABCD', 'NEW', @ebay, @ebay_credentials)
      product = Product.find(result)
      # As the item has been stubed with default sku as SKU
      expect(product.primary_sku).to eq 'SKU'
    end
  end

  context 'Generate Barcode' do
    it 'Generates Barcode image file' do
      image_name = helper.generate_barcode('ABCD')
      expect(File.exist?("#{Rails.root}/public/images/#{image_name}.png")).to eq true
    end
  end

  context 'Gives Weight format' do
    it 'gets weight format' do
      result = helper.get_weight_format('Any')
      expect(result).to eq result

      allow(GeneralSetting).to receive(:get_product_weight_format).and_return('ABCD')
      result = helper.get_weight_format(nil)
      expect(result).to eq 'ABCD'
    end
  end

  context 'GEt Product list' do
    it 'Gets Products list' do
      10.times do |n|
        product = FactoryGirl.create(:product)
        product_sku = FactoryGirl.create(:product_sku, sku: random_string, product: product)
        product_barcode = FactoryGirl.create(:product_barcode, barcode: random_string, product: product)
        product_inv_wh = FactoryGirl.create(
          :product_inventory_warehouse, product: product,
          inventory_warehouse_id: @inv_wh.id, available_inv: 25
        )
      end
      params = {filter: "active", sort: "sku", order: "DESC", is_kit: 0, limit: 20, offset: 0}
      result = helper.do_getproducts(params)
      expect(
        ProductSku.all.sort{|a,b| a.sku <=> b.sku}.reverse.map &:sku
        ).to eq result.map &:primary_sku

      params = {filter: "active", sort: "", order: "DESC", is_kit: 0, limit: 20, offset: 0}
      result = helper.do_getproducts(params)
      expect(result.count).to eq Product.count
    end
  end

  context 'Search Product list' do
    it 'Search Products list' do
      10.times do |n|
        product = FactoryGirl.create(:product)
        product_sku = FactoryGirl.create(:product_sku, sku: random_string, product: product)
        product_barcode = FactoryGirl.create(:product_barcode, barcode: random_string, product: product)
        product_inv_wh = FactoryGirl.create(
          :product_inventory_warehouse, product: product,
          inventory_warehouse_id: @inv_wh.id, available_inv: 25
        )
      end
      params = {search: ProductSku.first.sku, sort: "", order: "DESC", is_kit: 0, limit: 20, offset: 0}
      result = helper.do_search(params, false)
      expect(result['products'].map &:primary_sku).to include ProductSku.first.sku
    end
  end
end
