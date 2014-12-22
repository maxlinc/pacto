# -*- encoding : utf-8 -*-
describe Pacto do
  let(:contract_path) { "#{DEFAULT_CONTRACTS_DIR}/simple_contract.json" }
  let(:strict_contract_path) { "#{DEFAULT_CONTRACTS_DIR}/strict_contract.json" }

  before :all do
    WebMock.allow_net_connect!
  end

  context 'Contract investigation' do
    around :each do |example|
      run_pacto do
        example.run
      end
    end

    it 'verifies the contract against a producer' do
      # FIXME: Does this really test what it says it does??
      contract = described_class.load_contracts(contract_path, 'http://localhost:8000')
      expect(contract.simulate_consumers.map(&:successful?).uniq).to eq([true])
    end
  end

  context 'Stubbing a collection of contracts' do
    it 'generates a server that stubs the contract for consumers' do
      contracts = described_class.load_contracts(contract_path, 'http://dummyprovider.com')
      contracts.stub_providers

      response = get_json('http://dummyprovider.com/hello')
      expect(response['message']).to eq 'bar'
    end
  end

  context 'Journey' do
    it 'stubs multiple services with a single use' do
      described_class.configure do |c|
        c.strict_matchers = false
        c.register_hook Pacto::Hooks::ERBHook.new
      end

      contracts = described_class.load_contracts DEFAULT_CONTRACTS_DIR, 'http://dummyprovider.com'
      contracts.stub_providers(device_id: 42)

      login_response = get_json('http://dummyprovider.com/hello')
      expect(login_response.keys).to eq ['message']
      expect(login_response['message']).to be_kind_of(String)

      devices_response = get_json('http://dummyprovider.com/strict')
      expect(devices_response['devices'].size).to eq(2)
      expect(devices_response['devices'][0]).to eq('/dev/42')
      expect(devices_response['devices'][1]).to eq('/dev/43')
    end
  end

  def get_json(url)
    response = Faraday.get(url) do |req|
      req.headers = { 'Accept' => 'application/json' }
    end
    MultiJson.load(response.body)
  end
end
