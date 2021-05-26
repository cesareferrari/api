FactoryBot.define do
  factory :article do
    title { "Sample article" }
    content { "Sample content" }
    # slug { "sample-article" }

    sequence :slug do |n|
      "sample-article-#{n}"
    end
  end

end
