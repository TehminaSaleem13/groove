class AddProductreportIdProductgeneratedReportIdToAmazonCredentials < ActiveRecord::Migration
  def change
    add_column :amazon_credentials, :productreport_id, :string
    add_column :amazon_credentials, :productgenerated_report_id, :string
    add_column :amazon_credentials, :productgenerated_report_date, :datetime
  end
end
