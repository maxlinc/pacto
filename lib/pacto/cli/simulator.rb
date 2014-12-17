require 'pacto/cli/selector'

module Pacto
  module CLI
    class Simulator
      attr_reader :contracts, :shell, :options, :values, :consumer

      def initialize(contracts, shell, options = {})
        @contracts, @shell, @options = contracts, shell, options
        @values = load_params(options['params'])
        @consumer = Pacto::Consumer.new
        shell.extend Selector
      end

      def run
        if options[:interactive]
          run_interactive
        else
          run_non_interactive
        end
      end

      def run_interactive
        done = false
        until done
          api = shell.select(contracts, 'Which API would you like to use?') do |item|
            item.name
          end
          shell.say "You've selected to test #{api.name.inspect}"

          if api.examples?
            examples = api.examples.keys + [nil]
            example_name = shell.select(examples, 'Which example would you like to use?') do |name|
              name.nil? ? '(None)' : name
            end
          end

          if example_name.nil?
            shell.say 'No example will be used'
          else
            shell.say "Using example #{example_name}"
            example = api.examples.fetch example_name
          end

          shell.say 'Confirming values for required variables...'
          api.request.required_variables.each do |key|
            confirm key
          end

          request = consumer.build_request(api, values: values, example: example)
          shell.say 'Preparing to send request:'
          shell.say "URI: #{request.uri}"
          shell.say "Headers: #{request.headers.pretty_inspect}"
          shell.say "Body: #{request.raw_body}"

          abort 'Aborting...' unless shell.yes? 'Ready to send the request?'

          actual_request, actual_response = consumer.execute_request(request)

          shell.say 'Received response:'
          shell.say "Status: #{actual_response.status}"
          shell.say "Headers: #{actual_response.headers.pretty_inspect}"
          shell.say "Body: #{request.raw_body}"

          investigation = api.validate_response(actual_request, actual_response)

          shell.say 'Checking request/response against contract...'
          shell.say investigation

          done = shell.no? 'Would you test another service?'
        end
      end

      private

      def confirm(key)
        value = shell.ask "#{key} [#{values[key].inspect}]"
        values[key] = value unless value.empty?
      end

      def interactive?
        @options[:interactive]
      end

      def load_params(params_file)
        return {} if params_file.nil?

        Hashie::Mash.load(params_file).dup
      end
    end
  end
end
