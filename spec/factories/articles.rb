FactoryBot.define do
  factory :article do
    title { "Sample article" }
    content { "Sample content" }
    sequence :slug do |n|
      "sample-article-#{n}"
    end
  end
end
