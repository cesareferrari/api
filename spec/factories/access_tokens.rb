FactoryBot.define do
  factory :access_token do
    association :user
    # token { "MyString" }
    # user { nil }
  end
end
