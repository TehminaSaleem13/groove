require 'rails_helper'

RSpec.describe Role, type: :model do
  describe 'presence of name' do
    it 'role must have name' do
      role = Role.create(name: '')
      role.valid?
      role.errors.should have_key(:name)
    end
  end

  describe Role do
    it 'role should have uniq name' do
      Role.create(name: 'admin')
      role = Role.create(name: 'admin')
      expect(role).not_to be_valid
    end
  end

  it 'role  have many users' do
    role = Role.reflect_on_association(:users)
    expect(role.macro).to eq(:has_many)
  end
end
