# This is prepended to Mail::Message.
# https://github.com/mikel/mail/blob/master/lib/mail/message.rb
#
module MailMessageExtension

  # This method overrides the original delivery method in order to
  # handle cases where the message cannot be delivered. In those
  # cases, the email adress is marked as 'invalid'.
  #
  def deliver
    if recipient_address.include?('@')
      begin
        return super
      rescue Net::SMTPFatalError, Net::SMTPSyntaxError => error
        Rails.logger.debug error
        Rails.logger.warn "smtp-envelope-to field: #{self.smtp_envelope_to.to_s}"
        Rails.logger.warn "to field: #{self.to.to_s}"
        Rails.logger.warn "recognized recipient address (address only!): #{recipient_address}"
        Rails.logger.warn error.message
        recipient_address_needs_review!
        return false
      end
    else
      recipient_address_needs_review!
      return false
    end
  end
  
  def recipient_address
    self.smtp_envelope_to.try(:first) || self.to.try(:first)
  end
  
  def recipient_address_needs_review!
    raise 'no recipient address' unless recipient_address.present?
    if profile_field = ProfileFieldTypes::Email.where(value: recipient_address).first
      Rails.logger.warn "Adding :needs_review flag to email address #{recipient_address}."
      profile_field.needs_review!
    else
      Rails.logger.warn "Could not find matching email address #{recipient_address} in our database."
    end
  end

end