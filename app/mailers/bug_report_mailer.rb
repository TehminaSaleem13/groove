# frozen_string_literal: true

class BugReportMailer < ActionMailer::Base
  default from: 'app@groovepacker.com'

  def report_bug(data, user, tenant)
    @data = data
    @user = user
    @tenant = tenant
    file_name = @tenant + '_expo_logs.json'
    @general_setting = GeneralSetting.last
    @scanpack_setting = ScanPackSetting.last
    if @data[:url].present?
      @attachment_data = (begin
                            Net::HTTP.get(URI.parse(@data[:url]))
                          rescue StandardError
                            nil
                          end)
    end

    attachments[file_name] = @attachment_data if @attachment_data.present?

    subject = "Groovepacker [#{Rails.env}] - GPX #{@data[:identifier] == 'feedback' ? 'Feedback' : 'Bug Report'} [#{tenant}]"
    mail to: 'kcpatel006@gmail.com,groovepacker@gmail.com,support@groovepacker.com', subject: subject
  end
end
