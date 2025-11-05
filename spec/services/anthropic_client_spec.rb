require 'rails_helper'

RSpec.describe AnthropicClient do
  let(:api_key) { 'sk-ant-api03-valid-test-key' }
  let(:model) { 'claude-3-5-sonnet-20241022' }
  let(:client) { described_class.new(api_key: api_key, model: model) }

  describe '#test_connection' do
    context 'with valid API key', :vcr do
      it 'returns success with message' do
        result = client.test_connection

        expect(result[:success]).to be true
        expect(result[:message]).to include('Connected successfully')
      end
    end

    context 'with invalid API key', :vcr do
      let(:api_key) { 'sk-ant-api03-invalid-key' }

      it 'returns failure with authentication error' do
        result = client.test_connection

        expect(result[:success]).to be false
        expect(result[:message]).to include('Invalid API key')
      end
    end

    context 'with permission denied', :vcr do
      let(:api_key) { 'sk-ant-api03-no-opus-access' }
      let(:model) { 'claude-3-opus-20240229' }

      it 'returns failure with permission error' do
        result = client.test_connection

        expect(result[:success]).to be false
        expect(result[:message]).to include('Permission denied')
      end
    end

    context 'with network error' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post)
          .and_raise(Faraday::ConnectionFailed.new('Connection refused'))
      end

      it 'returns failure with network error message' do
        result = client.test_connection

        expect(result[:success]).to be false
        expect(result[:message]).to include('Network error')
      end
    end
  end

  describe '#complete' do
    it 'raises NotImplementedError with Phase 4 message' do
      expect {
        client.complete(prompt: 'test prompt')
      }.to raise_error(NotImplementedError, /Phase 4/)
    end
  end
end
