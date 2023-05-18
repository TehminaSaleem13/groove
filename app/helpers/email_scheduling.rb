module EmailScheduling
  def should_send_email(date)
    day = date.strftime('%A')
    result = false

    if day == 'Monday' && send_email_on_mon
      result = true
    elsif day == 'Tuesday' && send_email_on_tue
      result = true
    elsif day == 'Wednesday' && send_email_on_wed
      result = true
    elsif day == 'Thursday' && send_email_on_thurs
      result = true
    elsif day == 'Friday' && send_email_on_fri
      result = true
    elsif day == 'Saturday' && send_email_on_sat
      result = true
    elsif day == 'Sunday' && send_email_on_sun
      result = true
    end
    result
  end
end
