# frozen_string_literal: true

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :ftp_credential do
    store_id { 1 }
    host { 'MyString' }
    port { 45 }
    username { 'MyString' }
    password { 'MyString' }
    use_ftp_import { false }
  end
end
