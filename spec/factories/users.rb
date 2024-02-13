# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :user do
    sequence :username do |n|
      FactoryBot.create(:user, username: "user-#{n}-#{Time.current.to_i}")
    end
    password { '12345678' }
    password_confirmation { '12345678' }
    confirmation_code { rand(10**10).to_s }
    active { true }
  end
end
