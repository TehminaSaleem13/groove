require 'rails_helper'

RSpec.describe SettingsController, type: :controller do
  before(:each) do
    sup_ad = FactoryGirl.create(:role, name: 'super_admin1', make_super_admin: true)
    @user = FactoryGirl.create(:user, username: 'new_admin1', role: sup_ad)
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
end
