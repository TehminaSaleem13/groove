require 'spec_helper'

describe "orders/index" do
  before(:each) do
    assign(:orders, [
      stub_model(Order,
        :status => "Status",
        :storename => "Storename",
        :customercomments => "Customercomments",
        :store => nil
      ),
      stub_model(Order,
        :status => "Status",
        :storename => "Storename",
        :customercomments => "Customercomments",
        :store => nil
      )
    ])
  end

  it "renders a list of orders" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "tr>td", :text => "Status".to_s, :count => 2
    assert_select "tr>td", :text => "Storename".to_s, :count => 2
    assert_select "tr>td", :text => "Customercomments".to_s, :count => 2
    assert_select "tr>td", :text => nil.to_s, :count => 2
  end
end
