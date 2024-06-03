# frozen_string_literal: true

class FeaturesFormatter
  start_events = %i[seed start]
  example_events = %i[example_group_started example_started example_passed
                      example_failed example_pending example_finished]
  finish_events = %i[stop start_dump dump_pending dump_failures deprecation_summary
                     dump_profile dump_summary seed close]
  other_events = %i[deprecation message]
  custom_events = %i[example_will_be_retried]
  events = start_events + example_events + finish_events + other_events + custom_events

  RSpec::Core::Formatters.register self, *events

  def initialize(output)
    @output = output
  end

  events.each do |event|
    define_method event do |notification|
      output.puts "FORMATTER: #{event} #{notification.inspect}"
    end
  end

  private

  attr_reader :output
end
