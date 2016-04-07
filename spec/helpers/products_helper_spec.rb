require 'rails_helper'

RSpec.describe ProductsHelper, type: :helper do
  context 'Update Product with Amazon Product Details' do
    before(:each) do
      @inv_wh = FactoryGirl.create(
        :inventory_warehouse, name: 'amazon_inventory_warehouse'
      )
      @store = FactoryGirl.create(
        :store, name: 'amazon_store', inventory_warehouse: @inv_wh
      )
      @amazon_credentials = FactoryGirl.create(
        :amazon_credential, store_id: @store.id,
        import_images: true, import_products: true
      )
    end

    it 'updates the product' do
      product = FactoryGirl.create(:product)
      product_sku = FactoryGirl.create(:product_sku, :product=> product)
      product_barcode = FactoryGirl.create(:product_barcode, :product=> product)
      product_inv_wh = FactoryGirl.create(:product_inventory_warehouse, :product=> product,
                   :inventory_warehouse_id =>@inv_wh.id, :available_inv => 25)
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
    it 'Updates Editable products from product list'
  end
end
