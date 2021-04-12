class BugReportMailer < ActionMailer::Base
  default from: 'app@groovepacker.com'

  def report_bug(data, user, tenant)
    @data = data
    @user = user
    @tenant = tenant
    file_name = @tenant + '_expo_logs.json'
    @data = @data.permit!.to_h rescue @data
    File.write(Rails.root.join('log', file_name), JSON.pretty_generate(@data[:logs]))
    attachments[file_name] = File.read("log/#{file_name}")
    subject = "Groovepacker [#{Rails.env}] - Expo Bug Report [#{tenant}]"
    mail to: 'kcpatel006@gmail.com,groovepacker@gmail.com', subject: subject
  end
end
