# frozen_string_literal: true

module EmailScheduling
  WEEKDAYS = {
    monday: 'mon',
    tuesday: 'tue',
    wednesday: 'wed',
    thursday: 'thurs',
    friday: 'fri',
    saturday: 'sat',
    sunday: 'sun'
  }.freeze

  def should_send_email(date)
    day = date.strftime('%A').downcase.to_sym
    send_email_on_day = "send_email_on_#{WEEKDAYS[day]}".to_sym

    send(send_email_on_day)
  end
end
