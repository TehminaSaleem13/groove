require 'spec_helper'

describe ProductsController do
  before(:each) do 
    @user = FactoryGirl.create(:user, :import_orders=> "1")
    sign_in @user
  end

  describe "GET productimports" do
    it "imports all orders from magento store" do

      order = Order.create! valid_attributes
      get :importproducts
      assigns(:orders).should eq([order])
    end
  end
end
