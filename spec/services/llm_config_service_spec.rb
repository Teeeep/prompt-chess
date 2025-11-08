require 'rails_helper'

RSpec.describe LlmConfigService do
  let(:session) { {} }
  let(:api_key) { 'sk-ant-api03-test1234567890abcdef' }
  let(:model) { 'claude-3-5-haiku-20241022' }

  describe '.store' do
    it 'stores configuration in session' do
      LlmConfigService.store(
        session,
        provider: 'anthropic',
        api_key: api_key,
        model: model
      )

      expect(session[:llm_config]).to be_present
      expect(session[:llm_config][:provider]).to eq('anthropic')
      expect(session[:llm_config][:api_key]).to eq(api_key)
      expect(session[:llm_config][:model]).to eq(model)
    end

    it 'includes configured_at timestamp' do
      freeze_time do
        LlmConfigService.store(
          session,
          provider: 'anthropic',
          api_key: api_key,
          model: model
        )

        expect(session[:llm_config][:configured_at]).to eq(Time.current)
      end
    end
  end

  describe '.current' do
    context 'when configured' do
      before do
        LlmConfigService.store(
          session,
          provider: 'anthropic',
          api_key: api_key,
          model: model
        )
      end

      it 'returns current configuration' do
        config = LlmConfigService.current(session)

        expect(config[:provider]).to eq('anthropic')
        expect(config[:api_key]).to eq(api_key)
        expect(config[:model]).to eq(model)
        expect(config[:configured_at]).to be_present
      end
    end

    context 'when not configured' do
      it 'returns nil' do
        expect(LlmConfigService.current(session)).to be_nil
      end
    end
  end

  describe '.masked_key' do
    context 'when configured' do
      before do
        LlmConfigService.store(
          session,
          provider: 'anthropic',
          api_key: 'sk-ant-api03-test1234',
          model: model
        )
      end

      it 'returns last 4 characters of API key' do
        expect(LlmConfigService.masked_key(session)).to eq('...1234')
      end
    end

    context 'when not configured' do
      it 'returns nil' do
        expect(LlmConfigService.masked_key(session)).to be_nil
      end
    end
  end

  describe '.clear' do
    before do
      LlmConfigService.store(
        session,
        provider: 'anthropic',
        api_key: api_key,
        model: model
      )
    end

    it 'removes configuration from session' do
      LlmConfigService.clear(session)

      expect(session[:llm_config]).to be_nil
    end
  end

  describe '.configured?' do
    context 'when configured' do
      before do
        LlmConfigService.store(
          session,
          provider: 'anthropic',
          api_key: api_key,
          model: model
        )
      end

      it 'returns true' do
        expect(LlmConfigService.configured?(session)).to be true
      end
    end

    context 'when not configured' do
      it 'returns false' do
        expect(LlmConfigService.configured?(session)).to be false
      end
    end
  end
end
