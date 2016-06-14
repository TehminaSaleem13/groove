namespace :change_password do
	desc "change password for gpadmin user"
	task :gpadmin => :environment do
		Tenant.pluck(:name).each do |tenant|
			begin
				Apartment::Tenant.switch(tenant)
				User.find_by_name('gpadmin').update_attribute(:password,'098poi)(*POI')
			rescue => e
				puts 'Error occurred: ' + e.message
			end
		end
		exit(1)
	end

	desc "Create separate user and password for everybody"
	task :admintools => :environment do
		Apartment::Tenant.switch('admintools')
		%w(dan svisamsetty kalakar kapil ashish).each do |name|
			rand_no = Random.rand(99999999999)
			user = User.find_by_username(name)
			if user
				user.update_attribute(:password, name + '@1234')				
			else
				user = User.create(
					:username=>name,
					:password=>name + '@1234',
					:password_confirmation=>name + '@1234',
					:remember_me=>false,
					:confirmation_code=>rand_no
				)
			end
			user.update_attribute(:active, true)
			user.update_attribute(:role_id, 2)
		end
		exit(1)
	end
end
