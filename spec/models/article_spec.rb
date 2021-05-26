require 'rails_helper'

RSpec.describe Article, type: :model do
  describe "#validations" do
    let(:article)  { build(:article) }

    it "tests that factory is valid" do
      expect(article).to be_valid # article.valid? == true
    end

    it "requires a valid title" do
      article.title = '' 
      expect(article).not_to be_valid
      expect(article.errors['title']).to include("can't be blank")
    end

    it "requires a valid content" do
      article.content = '' 
      expect(article).not_to be_valid
      expect(article.errors['content']).to include("can't be blank")
    end

    it "requires a valid slug" do
      article.slug = '' 
      expect(article).not_to be_valid
      expect(article.errors['slug']).to include("can't be blank")
    end

    it "requires a unique slug" do
      article1 = create(:article)
      expect(article1).to be_valid
      article2 = build(:article, slug: article1.slug)
      expect(article2).not_to be_valid
      expect(article2.errors['slug']).to include("has already been taken")
    end
  end

  describe ".recent" do
    it 'returns articles in the correct order' do
      older_article = create(:article, created_at: 1.hour.ago)
      recent_article = create(:article)

      expect(described_class.recent).to eq([recent_article, older_article])

      recent_article.update_column(:created_at, 2.hours.ago)

      expect(described_class.recent).to eq([older_article, recent_article])
    end
  end
end
