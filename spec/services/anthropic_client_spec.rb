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
    context 'with valid prompt', :vcr do
      it 'returns completion with content and usage' do
        result = client.complete(prompt: 'Say "hello" in one word', max_tokens: 10)

        expect(result).to have_key(:content)
        expect(result).to have_key(:usage)
        expect(result[:content]).to be_a(String)
        expect(result[:usage]).to have_key(:input_tokens)
        expect(result[:usage]).to have_key(:output_tokens)
        expect(result[:usage]).to have_key(:total_tokens)
      end
    end

    context 'with network error' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post)
          .and_raise(Faraday::ConnectionFailed.new('Connection refused'))
      end

      it 'raises Faraday::Error' do
        expect {
          client.complete(prompt: 'test prompt')
        }.to raise_error(Faraday::Error)
      end
    end
  end
end
