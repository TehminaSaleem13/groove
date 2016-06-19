# ========================================
#                  USAGE
# ========================================
# // Ruby.
# Class OrderItem
#   ...
#   # this code generates some instance methods
#   # cached_product and cached_order_item_kit_products
#   # which when called the first time, will cache the ActiveRecord Object,
#   # and after every call will get the object back from the cache only.
#   # You can also cache the method results too.
#   # Also it creates cache check instance methods
#   # as in this case product_is_cached? And order_item_kit_products_is_cached?
# => cached_methods :product, :order_item_kit_products
#   # As the name suggests, this method will clear all the cache related
#   # to the class.
# => after_save :delete_cache
#   ...
# end
module CachedMethods
  extend ActiveSupport::Concern

  module ClassMethods
    def cached_methods(*methods)
      methods.each do |association|
        define_method("cached_#{association}") do |key = nil, cached = nil|
          key = "#{association}_for_#{self.class.to_s.underscore}_#{id}"
          cached = Rails.cache.read(key) rescue false
          return cached if cached
          load_assoc = send(association)
          Rails.cache.write(key, load_assoc, expires_in: 30.minutes)
          update_cache_keys(key)
          load_assoc
        end

        define_method("#{association}_is_cached?") do
          key = "#{association}_for_#{self.class.to_s.underscore}_#{id}"
          Rails.cache.read(key).present?
        end
      end
    end
  end

  private

  define_method('update_cache_keys') do |key|
    multi_key = "#{self.class.to_s.underscore}_#{id}_cache_keys"
    keys = Rails.cache.read(multi_key) || []
    keys << key
    Rails.cache.write(multi_key, keys.uniq)
  end

  def delete_cache
    cached = Rails.cache.read("#{self.class.to_s.underscore}_#{id}_cache_keys")
    return unless cached
    cached.each { |key| Rails.cache.delete(key) }
  end
end
