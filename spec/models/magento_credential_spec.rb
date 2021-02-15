require 'rails_helper'

RSpec.describe MagentoCredentials, type: :model do
  describe MagentoCredentials do
    it 'magento credential must have host' do
      magento_credentials = MagentoCredentials.create(host: '')
      magento_credentials.valid?
      magento_credentials.errors.should have_key(:host)
    end
  end

  describe MagentoCredentials do
    it 'magento credential must have username' do
      magento_credentials = MagentoCredentials.create(username: '')
      magento_credentials.valid?
      magento_credentials.errors.should have_key(:username)
    end
  end

  describe MagentoCredentials do
    it 'magento credential must have api key' do
      magento_credentials = MagentoCredentials.create(api_key: '')
      magento_credentials.valid?
      magento_credentials.errors.should have_key(:api_key)
    end
  end

  it 'magento credentials  should belongs to store' do
    magento_credentials = MagentoCredentials.reflect_on_association(:store)
    expect(magento_credentials.macro).to eq(:belongs_to)
  end
end
