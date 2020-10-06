# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :csv_import_summary do
    file_name { "MyString"}
    file_size { "MyString"}
    import_type {"MyString"}
  end
end
