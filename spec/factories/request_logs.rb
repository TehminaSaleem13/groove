# frozen_string_literal: true

FactoryBot.define do
  factory :request_log do
    request_method { 'MyString' }
    request_path { 'MyString' }
    request_body { 'MyText' }
    completed { false }
  end
end
