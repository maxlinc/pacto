# -*- encoding : utf-8 -*-
require 'pacto/generator/legacy_contract_generator'
require 'pacto/generator/hint'

module Pacto
  module Generator
    include Logger

    class << self
      # Factory method to return the active contract generator implementation
      def contract_generator
        NativeContractGenerator.new
      end

      # Factory method to return the active contract generator implementation
      def schema_generator
        JSON::SchemaGenerator
      end

      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration)
      end

      def hint_for(pacto_request)
        configuration.hints.find { |hint| hint.matches? pacto_request }
      end
    end

    class Configuration
      attr_reader :hints

      def initialize
        @hints = Set.new
      end

      def hint(name, request_data)
        hint_data = {
          service_name: name,
          target_file: request_data.delete(:target_file)
        }
        @hints << Pacto::Generator::Hint.new(hint_data, RequestClause.new(request_data))
      end
    end
  end
end
