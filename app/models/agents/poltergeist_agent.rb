module Agents
  class PoltergeistAgent < Agent
    include FormConfigurable

    can_dry_run!
    cannot_receive_events!

    form_configurable :url
    form_configurable :timeout
    default_schedule "every_12h"

    description <<-MD
      The PoltergeistAgent requests a page, and creates an event with the output of that request.
    MD

    event_description <<-EOM
      "Events will have the following fields: `output`"
    EOM

    def default_options
      {
        'url' => "http://google.com",
        'timeout' => "30",
        'expected_update_period_in_days' => "2"
      }
    end

    def working?
      event_created_within?(options['expected_update_period_in_days']) && !recent_error_logs?
    end

    def validate_options
      errors.add(:base, "a url must be specified") unless options['url'].present?
      errors.add(:base, "timeout must be an integer") unless options['timeout'] =~ /^[1-9][0-9]*$/
    end

    def check
      require 'capybara/poltergeist'
      Capybara.javascript_driver = :poltergeist
      Capybara.default_driver = :poltergeist

      Timeout.timeout(Integer(options['timeout'])) do
        browser = Capybara.current_session
        browser.visit(options['url'])

        create_event payload: { 'output' => browser.html }
      end
    end

  end
end
