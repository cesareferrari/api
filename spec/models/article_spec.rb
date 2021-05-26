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
end
