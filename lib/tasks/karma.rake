namespace :karma do
  task :install do
    system 'npm install -g karma'
    system 'npm install -g karma-cli'
    system 'npm install -g karma-jasmine'
    system 'npm install -g karma-bdd-using'
    system 'npm install -g karma-phantomjs-launcher'
    system 'npm install -g karma-chrome-launcher'

    exit(1)
  end

  task :start => :environment do
    with_tmp_config :start
    exit(1)
  end

  task :run => :environment do
    with_tmp_config :start, '--single-run'
    exit(1)
  end

  private

  def with_tmp_config(command, args = nil)
    Tempfile.open('karma_unit.js', Rails.root.join('tmp')) do |f|
      f.write unit_js(application_spec_files)
      f.flush

      system "karma #{command} #{f.path} #{args}"
    end
  end

  def application_spec_files
    sprockets = Rails.application.assets
    sprockets.append_path Rails.root.join('spec/javascripts/karma')
    files = Rails.application.assets.find_asset('application_spec.js').to_a.map { |e| e.pathname.to_s }
  end

  def unit_js(files)
    unit_js = File.open('spec/javascripts/karma/conf.js', 'r').read
    unit_js.gsub 'APPLICATION_SPEC', "\"#{files.join("\",\n\"")}\""
  end
end
