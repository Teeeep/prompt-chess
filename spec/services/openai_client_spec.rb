require 'rails_helper'

RSpec.describe OpenaiClient do
  let(:api_key) { ENV['OPENAI_API_KEY'] || 'sk-test-valid-key' }
  let(:model) { 'gpt-3.5-turbo' }
  let(:client) { described_class.new(api_key: api_key, model: model) }

  describe '#test_connection' do
    context 'with valid API key' do
      before do
        allow_any_instance_of(OpenAI::Client).to receive(:chat).and_return({
          'id' => 'chatcmpl-123',
          'choices' => [{ 'message' => { 'content' => 'Hi!' } }],
          'usage' => { 'prompt_tokens' => 10, 'completion_tokens' => 5, 'total_tokens' => 15 }
        })
      end

      it 'returns success with message' do
        result = client.test_connection

        expect(result[:success]).to be true
        expect(result[:message]).to include('Connected successfully')
      end
    end

    context 'with invalid API key' do
      let(:api_key) { 'sk-invalid-key-12345' }

      before do
        allow_any_instance_of(OpenAI::Client).to receive(:chat)
          .and_raise(Faraday::UnauthorizedError.new('Incorrect API key'))
      end

      it 'returns failure with authentication error' do
        result = client.test_connection

        expect(result[:success]).to be false
        expect(result[:message]).to include('Invalid API key')
      end
    end

    context 'with network error' do
      before do
        allow_any_instance_of(OpenAI::Client).to receive(:chat)
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
    context 'with valid prompt' do
      before do
        allow_any_instance_of(OpenAI::Client).to receive(:chat).and_return({
          'id' => 'chatcmpl-123',
          'choices' => [{ 'message' => { 'content' => 'Hello!' } }],
          'usage' => { 'prompt_tokens' => 12, 'completion_tokens' => 3, 'total_tokens' => 15 }
        })
      end

      it 'returns completion with content and usage' do
        result = client.complete(prompt: 'Say "hello" in one word', max_tokens: 10)

        expect(result).to have_key(:content)
        expect(result).to have_key(:usage)
        expect(result[:content]).to be_a(String)
        expect(result[:content]).to eq('Hello!')
        expect(result[:usage]).to have_key(:input_tokens)
        expect(result[:usage]).to have_key(:output_tokens)
        expect(result[:usage]).to have_key(:total_tokens)
      end
    end

    context 'with network error' do
      before do
        allow_any_instance_of(OpenAI::Client).to receive(:chat)
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
