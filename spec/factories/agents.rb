FactoryBot.define do
  factory :agent do
    name { "Chess Master #{rand(1000)}" }
    role { ['opening', 'tactical', 'positional', 'endgame'].sample }
    prompt_text { "You are a chess master specializing in #{role} play. You analyze positions deeply and suggest the best moves based on chess principles and tactics." }
    configuration { { temperature: 0.7, max_tokens: 500, top_p: 1.0 } }

    trait :opening do
      role { 'opening' }
      name { 'Opening Specialist' }
      prompt_text { 'You specialize in chess openings. You know all major opening systems including the Sicilian, French, Ruy Lopez, and King\'s Indian. You prioritize piece development, center control, and king safety in the opening phase.' }
    end

    trait :tactical do
      role { 'tactical' }
      name { 'Tactical Master' }
      prompt_text { 'You excel at tactical combinations. Look for forks, pins, skewers, discovered attacks, and sacrifices. Calculate forcing sequences deeply and find winning tactics.' }
    end

    trait :positional do
      role { 'positional' }
      name { 'Positional Player' }
      prompt_text { 'You focus on positional play. Control the center, improve piece placement, create pawn structure advantages, and restrict opponent pieces. Play for long-term advantages.' }
    end

    trait :minimal_config do
      configuration { {} }
    end

    trait :custom_config do
      configuration { { temperature: 0.9, max_tokens: 1000, custom_param: 'test_value' } }
    end
  end
end
