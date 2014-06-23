class Engine < Rails::Engine
  initializer 'Add remove assets directories from pipeline' do |app|
    theme_config_contents = YAML.load_file(Rails.root.join('config','theme.yml'))
    theme_config_contents['default'] ||= {}
    GROOVE_THEME = theme_config_contents['default'].merge(
        theme_config_contents['active'] || {} ).symbolize_keys
    app.config.assets.paths = Dir[Rails.root.join('app','themes',GROOVE_THEME[:identifier],'*')] + app.config.assets.paths
  end
end
