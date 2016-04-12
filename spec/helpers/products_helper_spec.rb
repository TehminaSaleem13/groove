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
      ProductsService::AmazonImport.any_instance.stub(:product_hash).and_return(amazon_produt_details)
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
        :ebay_credential, store_id: @store.id, productauth_token: 'test'
      )

      @ebay = EBay::API.new(@ebay_credentials.productauth_token,
                            ENV['EBAY_DEV_ID'], ENV['EBAY_APP_ID'],
                            ENV['EBAY_CERT_ID'])
      # class Item
      #   def initialize(hash)
      #     hash.each { |k, v| instance_variable_set("@#{k}", v) }
      #   end
      # end
      # item = Item.new(ebay_dummy_return_object)
      #
      # ProductsService::EbayImport.any_instance.stub(:item_from_ebay).and_return(item)

      # result = helper.import_ebay_product('ABCD', product_sku.sku, @ebay, @ebay_credential)
      # expect(result).to eq product.id
      #
      # result = helper.import_ebay_product('ABCD', 'NEW', @ebay, @ebay_credential)
      # expect(result).to eq product.id
    end
  end
end
