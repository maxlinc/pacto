# -*- encoding : utf-8 -*-
require 'faraday/response/pacto_logger'

ENHANCED_FARADAY_VERSION = Gem::Version.new('0.9.1')
if Gem::Version.new(Faraday::VERSION) >= ENHANCED_FARADAY_VERSION
  LOGGER_MIDDLEWARE = :logger
else
  Faraday::Response.register_middleware :pacto_logger => Faraday::Response::PactoLogger
  LOGGER_MIDDLEWARE = :pacto_logger
end

module Pacto
  class Consumer
    class FaradayDriver
      include Pacto::Logger
      # Sends a Pacto::PactoRequest
      def execute(req)
        conn_options = { url: req.uri.site }
        conn_options[:proxy] = Pacto.configuration.proxy if Pacto.configuration.proxy
        conn = Faraday.new(conn_options) do |faraday|
          faraday.response LOGGER_MIDDLEWARE, logger, faraday_logger_options
          faraday.adapter Faraday.default_adapter
        end

        response = conn.send(req.method) do |faraday_request|
          faraday_request.url(req.uri.path, req.uri.query_values)
          faraday_request.headers = req.headers
          faraday_request.body = req.raw_body
        end

        faraday_to_pacto_response response
      end

      private

      # This belongs in an adapter
      def faraday_to_pacto_response(faraday_response)
        data = {
          status: faraday_response.status,
          headers: faraday_response.headers,
          body: faraday_response.body
        }
        Pacto::PactoResponse.new(data)
      end

      def faraday_logger_options
        {
          :bodies => Pacto.configuration.log_bodies
        }
      end
    end
  end
end
