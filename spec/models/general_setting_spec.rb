require 'spec_helper'

RSpec.describe GeneralSetting, :type => :model do
  
  before(:each) do
    Groovepacker::SeedTenant.new.seed
    @generalsetting = GeneralSetting.all.first
    @generalsetting.update_column(:inventory_tracking,true)
  end

  it "should import orders on mon" do 
  	date = DateTime.civil_from_format :local, 2024, 12, 16
  	@generalsetting.update_attributes(import_orders_on_mon: true)
  	expect(@generalsetting.should_import_orders(date)).to eq true
  end

  it "should import orders on tue" do 
  	date = DateTime.civil_from_format :local, 2024, 12, 17
  	@generalsetting.update_attributes(import_orders_on_tue: true)
  	expect(@generalsetting.should_import_orders(date)).to eq true
  end

  it "should import orders on wed" do 
  	date = DateTime.civil_from_format :local, 2024, 12, 18
  	@generalsetting.update_attributes(import_orders_on_wed: true)
  	expect(@generalsetting.should_import_orders(date)).to eq true
  end

  it "should import orders on thurs" do 
  	date = DateTime.civil_from_format :local, 2024, 12, 19
  	@generalsetting.update_attributes(import_orders_on_thurs: true)
  	expect(@generalsetting.should_import_orders(date)).to eq true
  end

  it "should import orders on fri" do 
  	date = DateTime.civil_from_format :local, 2024, 12, 20
  	expect(@generalsetting.should_import_orders(date)).to eq false
  end

  it "should import orders on sat" do 
  	date = DateTime.civil_from_format :local, 2024, 12, 21
  	expect(@generalsetting.should_import_orders(date)).to eq false
  end

  it "should import orders on sun" do 
  	date = DateTime.civil_from_format :local, 2024, 12, 22
  	expect(@generalsetting.should_import_orders(date)).to eq false
  end

  # it "should import orders today" do
  # 	day = DateTime.now.strftime('%a')
  # 	@generalsetting.update_attributes(import_orders_on_mon: true, import_orders_on_tue: true, import_orders_on_wed: true, import_orders_on_thurs: true, import_orders_on_fri: true, import_orders_on_sat: true, import_orders_on_sun: true)
  # 	expect(@generalsetting.should_import_orders_today).to eq true
  # end

  # it "should not import orders today" do
  # 	day = DateTime.now.strftime('%a')
  # 	expect(@generalsetting.should_import_orders_today).to eq false
  # end

  # it "should import orders" do
  # 	date = DateTime.now
  # 	@generalsetting.update_attributes(import_orders_on_mon: true, import_orders_on_tue: true, import_orders_on_wed: true, import_orders_on_thurs: true, import_orders_on_fri: true, import_orders_on_sat: true, import_orders_on_sun: true)
  # 	expect(@generalsetting.should_import_orders(date)).to eq true
  # end

  # it "should not import orders" do
  # 	date = DateTime.now
  # 	expect(@generalsetting.should_import_orders(date)).to eq false
  # end

  # it "should import orders today" do
  # 	day = DateTime.now.strftime('%a')
  # 	@generalsetting.update_attributes(send_email_on_mon: true, send_email_on_tue: true, send_email_on_wed: true, send_email_on_thurs: true, send_email_on_fri: true, send_email_on_sat: true, send_email_on_sun: true)
  # 	expect(@generalsetting.should_send_email_today).to eq true
  # end

  # it "should not import orders today" do
  # 	day = DateTime.now.strftime('%a')
  # 	expect(@generalsetting.should_send_email_today).to eq false
  # end

  it "should send email on mon" do 
  	date = DateTime.civil_from_format :local, 2024, 12, 16
  	@generalsetting.update_attributes(send_email_on_mon: true)
  	expect(@generalsetting.should_send_email(date)).to eq true
  end

  it "should send email on tue" do 
  	date = DateTime.civil_from_format :local, 2024, 12, 17
  	@generalsetting.update_attributes(send_email_on_tue: true)
  	expect(@generalsetting.should_send_email(date)).to eq true
  end

  it "should send email on wed" do 
  	date = DateTime.civil_from_format :local, 2024, 12, 18
  	@generalsetting.update_attributes(send_email_on_wed: true)
  	expect(@generalsetting.should_send_email(date)).to eq true
  end

  it "should send email on thurs" do 
  	date = DateTime.civil_from_format :local, 2024, 12, 19
  	@generalsetting.update_attributes(send_email_on_thurs: true)
  	expect(@generalsetting.should_send_email(date)).to eq true
  end

  it "should send email on fri" do 
  	date = DateTime.civil_from_format :local, 2024, 12, 20
  	expect(@generalsetting.should_send_email(date)).to eq false
  end

  it "should send email on sat" do 
  	date = DateTime.civil_from_format :local, 2024, 12, 21
  	expect(@generalsetting.should_send_email(date)).to eq false
  end

  it "should send email on sun" do 
  	date = DateTime.civil_from_format :local, 2024, 12, 22
  	expect(@generalsetting.should_send_email(date)).to eq false
  end

  # it "should send email on mon" do
  # 	date = DateTime.now
  # 	@generalsetting.update_attributes(send_email_on_mon: true, send_email_on_tue: true, send_email_on_wed: true, send_email_on_thurs: true, send_email_on_fri: true, send_email_on_sat: true, send_email_on_sun: true)
  # 	expect(@generalsetting.should_send_email(date)).to eq true
  # end

  it "should not import orders" do
  	date = DateTime.now
  	expect(@generalsetting.should_send_email(date)).to eq false
  end

  it "should scheduled import" do
  	date = DateTime.now
  	expect(@generalsetting.scheduled_import).to eq true
  end 

  it "should send low inventory alert email" do
  	date = DateTime.now
  	expect(@generalsetting.send_low_inventory_alert_email).to eq true
  end 

  it "inventory state change check" do
  	expect(@generalsetting.inventory_state_change_check).to eq true
  end
end