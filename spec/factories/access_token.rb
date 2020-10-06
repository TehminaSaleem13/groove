FactoryBot.define do
  factory :access_token, class: 'Doorkeeper::AccessToken' do
    expires_in { 2.hours }
  end
end
