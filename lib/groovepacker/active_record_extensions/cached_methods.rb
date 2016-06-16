# creates a cached_method method for Models
# to eanble caching
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
          Rails.cache.read(key, expires_in: 30.minutes).present?
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
