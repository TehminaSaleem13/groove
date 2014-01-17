require 'spec_helper'

describe OrderTag do
   	it "should create a tag and associate with an order" do

      order = FactoryGirl.create(:order)
      order_tag = FactoryGirl.create(:order_tag)

      #order.order_tags << order_tag
      order_tag.orders << order

      order_tag.reload
      expect(order_tag.orders.length).to eq(1)
    end


end
