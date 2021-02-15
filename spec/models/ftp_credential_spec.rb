require 'rails_helper'

RSpec.describe FtpCredential, type: :model do
  it 'ftp credential should belongs to store' do
    ftp_credential = FtpCredential.reflect_on_association(:store)
    expect(ftp_credential.macro).to eq(:belongs_to)
  end
end
