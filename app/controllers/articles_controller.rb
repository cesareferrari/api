class ArticlesController < ApplicationController
  include Paginable

  def index
    paginated = paginate(Article.recent)
    render_collection(paginated)
  end

  def show
    render json: {}, status: :ok
  end

  def serializer
    ArticleSerializer
  end
end
