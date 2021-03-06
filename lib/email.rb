require 'mailgun'

module Firebots
  module Email

    def self.send(params)
      Thread.new do
        client.send_message('mg.fremontrobotics.com', params)
      end
    end

    def self.client
      @client ||= Mailgun::Client.new(Konfiguration.creds(:mailgun, :key))
    end

  end
end
