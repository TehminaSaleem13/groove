require 'rails_helper'

RSpec.describe SettingsController, type: :controller do

  before(:each) do
    sup_ad = FactoryGirl.create(:role, name: 'super_admin1', make_super_admin: true)
    @user = FactoryGirl.create(:user, username: 'new_admin1', role: sup_ad, name: 'testing')
    sign_in @user
    inv_wh = FactoryGirl.create(:inventory_warehouse, is_default: true)
  end

  context 'Restore from backups' do
    it 'must restore all Products from the backup file' do
      post :restore, {
        method: "del_import",
        file: fixture_file_upload(Rails.root.join('/files/restore.zip'))
      }
      [Product, ProductSku, ProductBarcode, ProductImage, ProductCat].each do |klass|
        expect(klass.count).to eq 3
      end
    end
  end

  context 'Export Order Exception' do
    it 'must export order_exceptions' do
      time_now = Time.zone.now
      order = FactoryGirl.create(:order, :increment_id=>'123-456')
      FactoryGirl.create(
        :order_exception, order: order, user: @user,
        reason: 'reason', description: 'description'
        )
      xhr :get, :order_exceptions, {
        start: time_now.ago(1.day), end: time_now.end_of_day
      }
      first_record = CSV.parse(response.body)[1]
      match_array = ['reason', 'description', 'testing (new_admin1)']
      expect(match_array - first_record).to eql []
    end
  end
end
