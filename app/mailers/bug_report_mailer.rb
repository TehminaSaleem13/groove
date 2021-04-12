class BugReportMailer < ActionMailer::Base
  default from: 'app@groovepacker.com'

  def report_bug(data, user, tenant)
    @data = data
    @user = user
    @tenant = tenant
    file_name = @tenant + '_expo_logs.json'
    if @data[:logs].present?
      File.write(Rails.root.join('log', file_name), JSON.pretty_generate(@data[:logs].as_json))
      attachments[file_name] = File.read("log/#{file_name}")
    end
    subject = "Groovepacker [#{Rails.env}] - Expo Bug Report [#{tenant}]"
    mail to: 'kcpatel006@gmail.com,groovepacker@gmail.com,gyanig72@gmail.com', subject: subject
  end
end
