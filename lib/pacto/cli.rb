require 'thor'
require 'pacto'
require 'pacto/cli/helpers'
require 'pacto/cli/simulator'

module Pacto
  module CLI
    class Main < Thor
      include Pacto::CLI::Helpers

      desc 'meta_validate [CONTRACTS...]', 'Validates a directory of contract definitions'
      def meta_validate(*contracts)
        invalid = []
        each_contract(*contracts) do |contract_file|
          begin
            Pacto.validate_contract(contract_file)
            say_status :validated, contract_file
          rescue InvalidContract => exception
            invalid << contract_file
            shell.say_status :invalid, contract_file, :red
            exception.errors.each do |error|
              say set_color("  Error: #{error}", :red)
            end
          end
        end
        abort "The following contracts were invalid: #{invalid.join(',')}" unless invalid.empty?
        say 'All contracts successfully meta-validated'
      end

      desc 'validate [CONTRACTS...]', 'Validates all contracts in a given directory against a given host'
      method_option :host, type: :string, desc: 'Override host in contracts for validation'
      def validate(*contracts)
        host = options[:host]
        WebMock.allow_net_connect!
        banner = 'Validating contracts'
        banner << " against host #{host}" unless host.nil?
        say banner

        invalid_contracts = []
        tested_contracts = []
        each_contract(*contracts) do |contract_file|
          tested_contracts << contract_file
          invalid_contracts << contract_file unless contract_is_valid?(contract_file, host)
        end

        validation_summary(tested_contracts, invalid_contracts)
      end

      desc 'simulate [CONTRACTS...]', 'Simulates requests sent from a consumer to a producer'
      method_option :interactive, lazy_default: true, desc: 'Allow prompts for input or confirmation'
      method_option :host, type: :string, desc: 'Override the host in the contract for sending requests'
      method_option :stub, lazy_default: true, desc: 'Used stubbed responses instead of sending to a real host'
      method_option :format, default: :default, enum: %w(swagger default), desc: 'The contract format being used'
      method_option :params, desc: 'A JSON or YAML file with parameters to use for the request'
      def simulate(*contract_files)
        contracts = ContractSet.new
        host, stub, format = options[:host], options[:stub], options[:format]

        each_contract(*contract_files) do |contract_file|
          contracts << Pacto.load_contract(contract_file, host, format)
        end

        if stub
          say_status :host, "#{host} (stubbed)"
          contracts.stub_providers
        else
          say_status :host, "#{host} (live)"
          WebMock.allow_net_connect!
        end
        banner = "Simulating requests for #{contracts.size} APIs"
        banner << " against host #{host}" unless host.nil?
        say banner

        Simulator.new(contracts, shell, options).run
      end

      private

      def validation_summary(contracts, invalid_contracts)
        if invalid_contracts.empty?
          say set_color("#{contracts.size} valid contract#{contracts.size > 1 ? 's' : nil}", :green)
        else
          abort set_color("#{invalid_contracts.size} of #{contracts.size} failed. Check output for detailed error messages.", :red)
        end
      end

      def contract_is_valid?(contract_file, host)
        name = File.split(contract_file).last
        contract = Pacto.load_contract(contract_file, host)
        investigation = contract.simulate_request

        if investigation.successful?
          say_status 'OK!', name
          true
        else
          say_status 'FAILED!', name, :red
          say set_color(investigation.summary, :red)
          say set_color(investigation.to_s, :red)
          false
        end
      end
    end
  end
end
