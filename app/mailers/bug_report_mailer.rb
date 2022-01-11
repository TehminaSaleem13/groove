class BugReportMailer < ActionMailer::Base
  default from: 'app@groovepacker.com'

  def report_bug(data, user, tenant)
    @data = data
    @user = user
    @tenant = tenant
    file_name = @tenant + '_expo_logs.json'
    @general_setting = GeneralSetting.last
    @scanpack_setting = ScanPackSetting.last
    @attachment_data = (Net::HTTP.get(URI.parse(@data[:url])) rescue nil) if @data[:url].present?

    attachments[file_name] = @attachment_data if @attachment_data.present?

    subject = "Groovepacker [#{Rails.env}] - Expo #{@data[:identifier] == 'feedback' ? 'Feedback' : 'Bug Report' } [#{tenant}]"
    mail to: 'kcpatel006@gmail.com,groovepacker@gmail.com,gyanig72@gmail.com', subject: subject
  end
end
