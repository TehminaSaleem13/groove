# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :orders_import_summary do
    total_retrieved 1
    success_imported 1
    previous_imported 1
    status false
    error_message "MyString"
    store nil
  end
end
