# Be sure to restart your server when you modify this file.

Groovepacks::Application.config.session_store :redis_session_store, {
    key: '_groovepacks_session',
    redis: {
        expire_after: 12.hours,
        key_prefix: 'groovepacks:session:',
        host:'localhost',
        port:6379
        #client: $redis
    }
}
#Groovepacks::Application.config.session_store :cookie_store, key: '_groovepacks_session'

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rails generate session_migration")
# Groovepacks::Application.config.session_store :active_record_store
