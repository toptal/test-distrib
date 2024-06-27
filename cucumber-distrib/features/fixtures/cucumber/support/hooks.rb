abort('Abort worker in root') if ENV['CUCUMBER_DISTRIB_ABORT_WORKER'] == 'true'

def raise_standard_error
  raise StandardError, 'Fail after configuration' if ENV['CUCUMBER_DISTRIB_FAIL_AFTER_CONFIGURATION'] == 'true'
end

if Gem.loaded_specs.fetch('cucumber').version >= Gem::Version.new('7')
  InstallPlugin { raise_standard_error }
else
  AfterConfiguration { raise_standard_error }
end

if ENV['CUCUMBER_DISTRIB_FAIL_WORLD'] == 'true'
  World do
    raise StandardError, 'Fail world'
  end
end

Before do |_scenario|
  sleep 1 if ENV['CUCUMBER_DISTRIB_MULTIPLE_WORKERS'] == 'true'
  raise StandardError, 'Fail before' if ENV['CUCUMBER_DISTRIB_FAIL_BEFORE'] == 'true'
end

After do |_result, _scenario|
  raise StandardError, 'Fail after' if ENV['CUCUMBER_DISTRIB_FAIL_AFTER'] == 'true'
end

AfterStep do |_result, _step|
  raise StandardError, 'Fail after step' if ENV['CUCUMBER_DISTRIB_FAIL_AFTER_STEP'] == 'true'
end
