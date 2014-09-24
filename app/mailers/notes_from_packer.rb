class NotesFromPacker < ActionMailer::Base
  default from: 'app@groovepacker.com'
  def send_email(mail_settings)
    @mail_data = mail_settings
    mail to: mail_settings['email'],
         subject: 'GroovePacker Note from packer'
  end
end
