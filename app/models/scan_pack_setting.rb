class ScanPackSetting < ActiveRecord::Base
  attr_accessible :ask_tracking_number, :enable_click_sku
  def self.is_action_code(code)
    setting = self.all.first
    string_code = code.to_s
    return (
      (string_code == setting.skip_code.to_s) ||
      (string_code == setting.note_from_packer_code) ||
      (string_code == setting.service_issue_code) ||
      (string_code == setting.restart_code)
    )
  end
end
