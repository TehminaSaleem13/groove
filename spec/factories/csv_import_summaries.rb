# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :csv_import_summary do
    file_name "MyString"
    file_size "MyString"
    import_type "MyString"
  end
end
