# Inculde custom enxtensions here
module ActiveRecordExtension
  extend ActiveSupport::Concern
  included do
    include CachedMethods
  end
end

# include the extension
ActiveRecord::Base.send(:include, ActiveRecordExtension)
