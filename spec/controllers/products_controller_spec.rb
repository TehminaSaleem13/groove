require 'spec_helper'

describe ProductsController do
  before(:each) do 
    @user = FactoryGirl.create(:user, :import_orders=> "1")
    sign_in @user
  end
  
  describe "SET product alias" do
    it "sets an alias and copies skus and barcodes" do
      request.accept = "application/json"

      product_orig = FactoryGirl.create(:product)
      product_orig_sku = FactoryGirl.create(:product_sku, :product=> product_orig)
      product_orig_barcode = FactoryGirl.create(:product_barcode, :product=> product_orig)

      product_alias = FactoryGirl.create(:product, :name=>"Apple iPhone5C")
      product_alias_sku = FactoryGirl.create(:product_sku, :product=> product_alias, :sku=>'iPhone5C')
      product_alias_barcode = FactoryGirl.create(:product_barcode, :product=> product_alias, :barcode=>"2456789")

      put :setalias, { :product_orig_id => product_orig.id, :product_alias_id => product_alias.id }

      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result["status"]).to eq(true)
      product_orig.reload
      expect(product_orig.product_skus.length).to eq(2)
      expect(product_orig.product_barcodes.length).to eq(2)
      expect(Product.all.length).to eq(1)
    end
  end

end
