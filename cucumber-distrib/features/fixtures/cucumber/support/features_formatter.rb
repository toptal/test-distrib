require 'cucumber/formatter/io'

class FeaturesFormatter
  include Cucumber::Formatter::Io

  WORKER_ONLY_EVENTS = %i[step_definition_registered gherkin_source_read]

  COMMON_EVENTS = %i[
    test_run_started
    test_case_started test_step_started
    step_activated
    test_step_finished test_case_finished
    test_run_finished
  ]

  def initialize(config)
    events = WORKER_ONLY_EVENTS + COMMON_EVENTS

    if defined?(Cucumber::Distrib)
      events << :retrying_test
      # :test_reported is present only in `worker_registry`
      # See: lib/cucumber/distrib/events.rb
      events << :test_reported if Cucumber::Distrib.worker?
    end

    events.each do |e|
      config.on_event(e) do |event|
        puts "FORMATTER: #{e} #{event.inspect}"
      end
    end
  end
end
