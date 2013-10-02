require 'spec_helper'

describe "orders/show" do
  before(:each) do
    @order = assign(:order, stub_model(Order,
      :status => "Status",
      :storename => "Storename",
      :customercomments => "Customercomments",
      :store => nil
    ))
  end

  it "renders attributes in <p>" do
    render
    # Run the generator again with the --webrat flag if you want to use webrat matchers
    rendered.should match(/Status/)
    rendered.should match(/Storename/)
    rendered.should match(/Customercomments/)
    rendered.should match(//)
  end
end
