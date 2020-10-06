# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryBot.define do
  factory :csv_import_log_entry do
    index {1}
    csv_import_summary_id {1}
  end
end
