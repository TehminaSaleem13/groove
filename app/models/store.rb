class Store < ActiveRecord::Base
  attr_accessible :name, :order_date, :status, :store_type
  
  has_one :magento_credentials
  has_one :ebay_credentials
  has_one :amazon_credentials

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_associated :magento_credentials
  validates_associated :amazon_credentials
  validates_associated :ebay_credentials

  def get_store_credentials
  	@result = Hash.new
  	if self.store_type == 'Amazon'
  		@credentials = AmazonCredentials.where(:store_id => self.id)
  		if !@credentials.nil? && @credentials.length > 0
  			@result['amazon_credentials'] = @credentials.first
  		end
  	end
  	if self.store_type == 'Ebay'
  		@credentials = EbayCredentials.where(:store_id => self.id)
  		if !@credentials.nil? && @credentials.length > 0
  			@result['ebay_credentials'] = @credentials.first
  		end
  	end
  	if self.store_type == 'Magento'
  		@credentials = MagentoCredentials.where(:store_id => self.id)
  		if !@credentials.nil? && @credentials.length > 0
  			@result['magento_credentials'] = @credentials.first
  		end
  	end
  	@result
  end

  def deleteauthentications
    @result = true
    if self.store_type == 'Amazon'
      @credentials = AmazonCredentials.where(:store_id => self.id)
    end
    if self.store_type == 'Ebay'
      @credentials = EbayCredentials.where(:store_id => self.id)
    end
    if self.store_type == 'Magento'
      @credentials = MagentoCredentials.where(:store_id => self.id)
    end

    if !@credentials.nil? && @credentials.length > 0
      if !(@credentials.first.destroy)
        @result= false
      end
    end
    @result
  end

  def dupauthentications(id)
    @result = true
    if self.store_type == 'Amazon'
      @credentials = AmazonCredentials.where(:store_id => id)
      if !@credentials.nil? && @credentials.length > 0
        @newcredentials = AmazonCredentials.new 
        @newcredentials = @credentials.first.dup
        @newcredentials.store_id = self.id
        if !@newcredentials.save
          @result = false
        end
      end
    end
    if self.store_type == 'Ebay'
      @credentials = EbayCredentials.where(:store_id => id)
      if !@credentials.nil? && @credentials.length > 0
        @newcredentials = EbayCredentials.new 
        @newcredentials = @credentials.first.dup
        @newcredentials.store_id = self.id
        if !@newcredentials.save
          @result = false
        end
      end
    end
    if self.store_type == 'Magento'
      @credentials = MagentoCredentials.where(:store_id => id)
      if !@credentials.nil? && @credentials.length > 0
        @newcredentials = MagentoCredentials.new 
        @newcredentials = @credentials.first.dup
        @newcredentials.store_id = self.id
        if !@newcredentials.save
          @result = false
        end
      end
    end
    @result
  end

end
