require 'rails_helper'

RSpec.describe DashboardController, :type => :controller do
  before(:each) do
    @user_role = FactoryGirl.create(:role,:name=>'spec_tester_role')
    @user = FactoryGirl.create(:user,:name=>'Tester', :username=>"spec_tester", :role => @user_role)
    sign_in @user

    @user_role1 = FactoryGirl.create(:role,:name=>'spec_tester_role1')
    @user1 = FactoryGirl.create(:user,:name=>'Tester1', :username=>"spec_tester1", :role => @user_role1, :confirmation_code=> "1234567891")
    @user2 = FactoryGirl.create(:user,:name=>'Tester2', :username=>"spec_tester2", :role => @user_role1, :confirmation_code=> "1234567892")

    @order1 = FactoryGirl.create(:order, :status=>'scanned', :packing_user_id=> @user1.id, :increment_id=>'1234567890')
    @order_exception1 = FactoryGirl.create(:order_exception, :reason=>'incorrect_item', :description=>'incorrect_item', :user_id=> @user1.id, :order_id=> @order1.id)
    sleep(1)
    @order2 = FactoryGirl.create(:order, :status=>'scanned', :packing_user_id=> @user2.id, :increment_id=>'2234567890')
    @order_exception2 = FactoryGirl.create(:order_exception, :reason=>'incorrect_item', :description=>'incorrect_item', :user_id=> @user2.id, :order_id=> @order2.id)
  end

  describe 'Show all exception ' do
    it 'if user_id is -1' do
      request.accept = "application/json"
      get :exceptions, {:user_id => '-1', :exception_type => 'most_recent'}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result.size).to eq(2)
    end

    it 'depending on the selected filter type' do
      request.accept = "application/json"
      get :exceptions, {:user_id => '-1', :exception_type => 'most_recent'}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result.size).to eq(2)
      expect(result.first['recorded_at']).to be > result.last['recorded_at']
    end
  end

  describe 'Show only related exceptions ' do
    it 'if user is selected' do
      request.accept = "application/json"
      get :exceptions, {:user_id => @user1.id, :exception_type => 'most_recent'}
      expect(response.status).to eq(200)
      result = JSON.parse(response.body)
      expect(result.size).to eq(1)
      expect(result.first['order_id']).to eq(@order1.id)
    end
  end
end