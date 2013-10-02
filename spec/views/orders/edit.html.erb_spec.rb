require 'spec_helper'

describe "orders/edit" do
  before(:each) do
    @order = assign(:order, stub_model(Order,
      :status => "MyString",
      :storename => "MyString",
      :customercomments => "MyString",
      :store => nil
    ))
  end

  it "renders the edit order form" do
    render

    # Run the generator again with the --webrat flag if you want to use webrat matchers
    assert_select "form[action=?][method=?]", order_path(@order), "post" do
      assert_select "input#order_status[name=?]", "order[status]"
      assert_select "input#order_storename[name=?]", "order[storename]"
      assert_select "input#order_customercomments[name=?]", "order[customercomments]"
      assert_select "input#order_store[name=?]", "order[store]"
    end
  end
end
