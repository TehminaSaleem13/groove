# frozen_string_literal: true

# include the extension
ActiveRecord::Base.send(:include, CachedMethods)
