# README

---

title: Testing and implementing pagination in a Rails API
subtitle:
slug: testing-implementing-pagination-in-rails-api
cover_image:
date: 2021-05-28T12:55:07
author: Cesare Ferrari
categories: ["api", "rails"]
published: true

---

In my Rails API I want to allow the user to specify pagination
parameters for resource collections.

The JSON API specification explains how fetching
[pagination](https://jsonapi.org/format/#fetching-pagination)
should be treated.

The URL should have `page[number]` and `page[size]` keys. `number` refers to the
page number in the total number of pages, and `size` refers to the number of
items returned in each page.

```
http://localhost:3000/articles?page[number]=2&page[size]=1
```

The response should have a `meta` key with total number of pages, and a list of
links to handle pagination.

```
{
    "data": [
        {
            "id": "4",
            "type": "article",
            "attributes": {
                "title": "Sunny day",
                "content": "Today is sunny",
                "slug": "sunny-day"
            }
        }
    ],
    "meta": {
        "total": 2,
        "pages": 2
    },
    "links": {
        "self": "http://localhost:3000/articles?page[size]=1",
        "next": "http://localhost:3000/articles?page[number]=2&page[size]=1",
        "last": "http://localhost:3000/articles?page[number]=2&page[size]=1"
    }
}
```

## Writing the spec

In the spec, I create 3 articles using the `create_list` method of `FactoryBot`.
This method takes a parameter that specifies how many items to create.

I then send the request to the server passing pagination parameters with
it.

In this spec I am also using the `json_data` helper to facilitate writing the
specs.

```
# spec/requests/articles_spec.rb

    it 'paginates results' do
      article1, article2, article3 = create_list(:article, 3)
      get '/articles', params: { page: { number: 2, size: 1 } }
      expect(json_data.length).to eq(1)
      expect(json_data.first[:id]).to eq(article2.id.to_s)
    end
```

The response should also include pagination links, so I will be testing that as
well:

```
# spec/requests/articles_spec.rb
    it 'contains pagination links in the response' do
      article1, article2, article3 = create_list(:article, 3)
      get '/articles', params: { page: { number: 2, size: 1 } }
      expect(json[:links].length).to eq(5)
      expect(json[:links].keys).to contain_exactly(
        :first,
        :prev,
        :next,
        :last,
        :self,
      )
    end
```

## Implementing pagination

Popular Ruby gems used for pagination are `kaminari` and `will_paginate`, but I
will use [`pagy`](https://github.com/ddnexus/pagy), together with
[`jsom-pagination`](https://github.com/useo-pl/jsom-pagination), a wrapper
around `pagy` that makes it easy to use in a Rails API.

I install it by adding it to the Gemfile and running `bundle`:

```
 # Gemfile

gem 'jsom-pagination', '~> 0.1.3'
```

To paginate the response, I need a paginator which is an instance of
`JSOM::Pagination::Paginator`.

I create a new method in `ArticlesController` that returns this instance:

```
 # app/controllers/articles_controller.rb

  def paginator
    JSOM::Pagination::Paginator.new
  end
```

the `paginator` takes 3 arguments:

1. the collection being paginated
2. a pagination params hash
3. the base url used to generate links to the previous/next page

```
 # app/controllers/articles_controller.rb

  def index
    articles = Article.all

    paginated = paginator.call(
      articles, 
      params: pagination_params, 
      base_url: request.url
      )

    render json: serializer.new(paginated.items), status: :ok
  end
```

I save the `paginator` into a `paginated` variable and pass it to the
serializer.

The `pagination_params` method in the controller allows the `page` parameter to be accessed by the Rails app, and looks like this:

```
 # app/controllers/articles_controller.rb

  def pagination_params
    params.permit![:page]
  end
```

According to the JSON format I am implementing, I now need to add the `meta` and
`links` keys to the response.

This is done by adding those keys in an `options` hash, passed as the second parameter to the serializer.

```
options = {meta: paginated.meta.to_h, links: paginated.links.to_h}
render json: serializer.new(paginated.items, options), status: :ok
```

At this point, the tests should pass.


## Refactoring

Since the pagination methods will be used in other controllers I am extracting
them into a pagination module, to be included in controllers that need it.

I add a new file in `app/controllers/concerns` called paginable.rb, with
this code.

```
module Paginable
  extend ActiveSupport::Concern

  def paginate(collection)
    paginator.call(collection, params: pagination_params, base_url: request.url)
  end

  def paginator
    JSOM::Pagination::Paginator.new
  end

  def pagination_params
    params.permit![:page]
  end

  def render_collection(paginated)
    options = { meta: paginated.meta.to_h, links: paginated.links.to_h }
    result = serializer.new(paginated.items, options)
    render json: result, status: :ok
  end
end
```

After removing the methods from the controller, and including the `Paginable`
module, the `index` action looks like this:

```
# app/controller/articles_controller.rb

  include Paginable

  def index
    paginated = paginate(Article.recent)
    render_collection(paginated)
  end
```









# Published Articles

Articles below are published on my blog.

---

title: Testing Rails API requests
subtitle:
slug: testing-rails-api-requests
cover_image:
date: 2021-05-27T00:00:00
author: Cesare Ferrari
categories: ["api", "rails"]
published: true

---

I can write request specs to test a Rails controller response to API
requests.

I create a new `requests` directory inside `spec` and add a file named
`articles_spec.rb` to test the `ArticlesController` methods.

If I use a single file, I can nest `describe` blocks to group specs that test
the same controller method.

For example, if I am testing the `index` method I can group tests in this way:

```
RSpec.describe ArticlesController do
  describe '#index' do
    it 'returns a success response' do
    ...
    end
  end
end
```

The first test is to check for an appropriate response:

```
  it 'returns a success response' do
    get '/articles'

    # expect(response.status).to eq(200)
    expect(response).to have_http_status(:ok)
  end
```

I can make this test pass by rendering an empty JSON object (the status code is
not necessary in this case because it defaults to 200).

```
def index
  render json: {}, status: :ok
end
```

## Testing the body of the request

Next I write a spec that checks that the response contains an expected body.
I first create an article, then send a GET request to the `/articles` endpoint.
This will return a JSON object in the response `body`.

I can convert the JSON to a more convenient Ruby hash by calling `JSON.parse()` on
it.

In my expectation I compare the returned body to the format I am expecting.
I am expecting a `data` object with an array containing a list of articles.
Inside each article is an `id`, `type` of resource, and attributes objects.

The format is JSON API, and it's described in this note: [JSON API format](/posts/json-api-format)

```
  it 'returns a proper JSON' do
    article = create :article

    get '/articles'
    body = JSON.parse(response.body)

    expect(body).to eq(
      data: [
        {
        id: article.id.to_s,
        type: 'article',
          attributes: {
            title: article.title,
            content: article.content,
            slug: article.slug
          }
        }
      ]
    )
  end
```

I can fetch all the articles with `ActiveRecord.all` and the `render` method in the controller will return JSON to the browser, but the format and the attributes returned are different from the specification.

I can fix this problem by serializing the JSON response manually instead of
using the default `ActiveRecord` format.
For this purpose I use the [`jsonapi-serializer`](https://github.com/jsonapi-serializer/jsonapi-serializer) gem.

```
# Gemfile

gem 'jsonapi-serializer', '~> 2.2'
```

Once installed with `bundle` and restarted the server, I create an article
serializer class using the generator provided by the gem. After the name of the
model, I can add a list of attributes that I want to return in the JSON
response:

```
rails g serializer article title content slug
```

This command will create an `ArticleSerializer` class inside the `app/serializers` directory with this content:

```
class ArticleSerializer
  include JSONAPI::Serializer
  attributes :title, :content, :slug
end
```

I will initialize an instance of the class and pass an Article object to its constructor

To use the serializer I define a `serializer` method inside the
`ArticlesController` that returns the class.

```
# app/controllers/articles_controller.rb

def serializer
  ArticleSerializer
end
```

In the `index` action, I return the serialized list of articles:

```
# app/controllers/articles_controller.rb

def index
  articles = Article.all
  render json: serializer.new(articles), status: :ok
end
```

This returns the JSON in the correct format:

```
{
    "data": [
        {
            "id": "4",
            "type": "article",
            "attributes": {
                "title": "Sunny day",
                "content": "Today is sunny",
                "slug": "sunny-day"
            }
        },
        {
            "id": "3",
            "type": "article",
            "attributes": {
                "title": "Rainy day",
                "content": "Today is raining",
                "slug": "rainy-day"
            }
        }
    ],
}
```

The test should still fail because in my expectations I am expecting Ruby
`symbols` as keys in the hash, but the JSON returned has `strings` instead.

I fix this by adding the method `deep_symbolize_keys` to the returned JSON. This
will convert string keys to symbols and match my expectation.

```
body = JSON.parse(response.body).deep_symbolize_keys
```

## Refactoring

The code that converts the JSON object to a Ruby hash in my tests can be
extracted into a helper method.

I create a new file inside `spec/support` named `api_helpers.rb`. Inside this
file I add a module with two methods: `json` and `json_data`.

`json` will parse the JSON object in the response and convert it to a Ruby hash,
with keys converted into symbols.

`json_data` will extract the `data` object provided by the API from the
response, so it's easier to work with it.

```
# spec/support/api_helpers.rb

module ApiHelpers
  def json
    JSON.parse(response.body).deep_symbolize_keys
  end

  def json_data
    json[:data]
  end
end
```

This file is not loaded by default in my tests, so I open the `rails_helper.rb`
file and uncomment the following line:

```
# rails_helper.rb

Dir[Rails.root.join('spec', 'support', '**', '*.rb')].sort.each { |f| require f }
```

Then, in the `configure` block I can add the `ApiHelpers` module, so I can call
the methods directly:

```
# rails_helper.rb

  config.include ApiHelpers
```

Now, in the spec, I can use these methods:

```
  expect(json_data).to eq(
    [
      {
      id: article.id.to_s,
      type: 'article',
        attributes: {
          title: article.title,
          content: article.content,
          slug: article.slug
        }
      }
    ]
  )
```

In the spec, I can easily check the length of the returned array:

```
  expect(json_data.length).to eq(1)
```

I can also extract the first element of the array into an `expected` variable
and check its attributes:

```
    expected = json_data.first

    expect(expected[:id]).to eq(article.id.to_s)
    expect(expected[:type]).to eq('article')
    expect(expected[:attributes]).to eq(
      title: article.title,
      content: article.content,
      slug: article.slug,
    )
```

This way makes the output of the tests more readable and easier to catch bugs or
errors in the code.

## Complete code

```
require 'rails_helper'

RSpec.describe ArticlesController do
  describe '#index' do
    it 'returns a success response' do
      get '/articles'

      # expect(response.status).to eq(200)
      expect(response).to have_http_status(:ok)
    end

    it 'returns a proper JSON' do
      article = create :article
      get '/articles'
      expect(json_data.length).to eq(1)
      expected = json_data.first

      aggregate_failures do
        expect(expected[:id]).to eq(article.id.to_s)
        expect(expected[:type]).to eq('article')
        expect(expected[:attributes]).to eq(
          title: article.title,
          content: article.content,
          slug: article.slug,
        )
      end
    end

    it 'returns articles in the proper order' do
      older_article = create(:article, created_at: 1.hour.ago)
      recent_article = create(:article)
      get '/articles'
      ids = json_data.map { |item| item[:id].to_i }

      expect(ids).to eq([recent_article.id, older_article.id])
    end

    it 'paginates results' do
      article1, article2, article3 = create_list(:article, 3)
      get '/articles', params: { page: { number: 2, size: 1 } }
      expect(json_data.length).to eq(1)
      expect(json_data.first[:id]).to eq(article2.id.to_s)
    end

    it 'contains pagination links in the response' do
      article1, article2, article3 = create_list(:article, 3)
      get '/articles', params: { page: { number: 2, size: 1 } }
      expect(json[:links].length).to eq(5)
      expect(json[:links].keys).to contain_exactly(
        :first,
        :prev,
        :next,
        :last,
        :self,
      )
    end
  end
end
```

---

title: Create a file in a new directory in Vim
subtitle:
slug: vim-create-directory
cover_image:
date: 2021-05-27
author: Cesare Ferrari
categories: ["vim"]
published: true

---

In Vim, I enter explorer mode with `:e .`, or `:Explorer`.
This will show the filesystem.

I navigate to the desired location where I want to create the new directory and
type `d`. Vim will ask for a directory name. Once entered, Vim creates the
directory.

I can then enter this directory and type `%` to add a file name. On pressing
`enter` Vim will create the new file.

---

title: Testing Rails API routing
subtitle:
slug: testing-rails-api-routing
cover_image:
date: 2021-05-27
author: Cesare Ferrari
categories: ["rails", "api", "testing"]
published: true

---

Since the Rails REST API will be accessed through a series of routes, I set up some routing tests before adding the actual routes.

Routing tests are different from requests tests, because they only test that
appropriate routes are defined in the application and those routes direct the
requests to the correct controller and action.

Requests tests will be described in other articles.

## Routing spec folder

Inside the `spec` folder I create a new directory called `routing` with a file
named `articles_spec.rb` in it.

```
mkdir spec/routing
touch spec/routing/articles_spec.rb
```

With the specs, I only check if the routes point to a specific controller and
action, however there are a couple of different syntaxes that I can use to check if a
route exists:

```
expect(get '/articles').to route_to(controller: 'articles', action: 'index')

# same as:

expect(get '/articles').to route_to('articles#index')
```

## Route parameters

If the route takes parameters, for example an `id`, they can be specified
in this way:

```
expect(get '/articles/1').to route_to('articles#show', id: '1')
```

If I have nested parameters, like for a page number request for example, I can
describe the nested structure like so:

```
expect(get '/articles?page[number]=3').to route_to(
  'articles#index',
  page: {
    number: '3',
  },
)
```

## Parameters as strings

Route parameters are passed to Rails as strings, so if a param is a number in
the URL, it will be converted to a string, so I need to take care to make the
correct test expectation:

```
# wrong: 1 is an integer
route_to('articles#show', id: 1)

# correct: 1 is a string
route_to('articles#show', id: '1')
```

## Viewing routes in the application

I can view the routes defined in the Rails application with the `rails routes`
command.

To filter the output of the command I can specify the `-g` flag like so:

```
$ rails routes -g articles

  Prefix Verb URI Pattern             Controller#Action
articles GET  /articles(.:format)     articles#index
 article GET  /articles/:id(.:format) articles#show
```

## Complete example

```
require 'rails_helper'

RSpec.describe '/articles routes' do
  it 'routes to articles#index' do
    expect(get '/articles').to route_to('articles#index')
  end

  it 'routes to articles/:id' do
    expect(get '/articles/1').to route_to('articles#show', id: '1')
  end
end
```

## Implementing the routes

To make the above tests pass, I implement the routes in `config/routes.rb`

```
# config/routes.rb

Rails.application.routes.draw do
  resources :articles, only: [:index, :show]
end
```

---

title: Testing a Rails model with RSpec and FactoryBot
subtitle:
slug: testing-rails-model
cover_image:
date: 2021-05-27
author: Cesare Ferrari
categories: ["rails", "api", "testing"]
published: true

---

I add an Article resource:

```
rails g model article title content:text slug
```

This generates the `Article` model as well as the migration for creating the
database table named `articles`, with `title`, `content`, and `slug` columns.

The generator also creates a `spec/models/article_spec.rb` file for testing the
article, and a `spec/factories/articles.rb` file to specify test factories for the
tests.

I run the migration with `rail db:migrate`

## Testing the model

I start by writing specs for validating the model.

I can use `FactoryBot` to create dummy objects for testing.

In the `spec/factories/articles.rb` file, I can start defining the attributes of my
Article model.
Since the `slug` needs to be unique, I can have `FactoryBot` generate a sequence
of slugs calling the sequence method and passing a block to it that defines the slug
string interpolating a different number for each slug created.

```
# spec/factories/articles.rb

FactoryBot.define do
  factory :article do
    title { "Sample article" }
    content { "Sample content" }
    sequence :slug do |n|
      "sample-article-#{n}"
    end
  end
end
```

Then I can use the `create` method of `FactoryBot` to create the article in the
test file:

```
# spec/models/article_spec.rb

require 'rails_helper'

RSpec.describe Article, type: :model do
  it 'tests articles' do
    article = create(:article)
    expect(article.title).to eq('Sample article')
  end
end
```

Since the `FactoryBot` syntax method have been included in the `rails_helper`, I
can call them directly.

## Testing model validation

In order to avoid creating objects in the database and speed up testing, I can
use the `build` method of `FactoryBot`, to create an object in memory.

Default values set in the factory file can be overriden by passing arguments like so:

```
article = build(:article, slug: "custom-slug")
```

To keep the tests organized, I add nested `describe` blocks for each feature I
am testing.

In the case of validations, I add the text `'#validations'`, prefixed by a `#`
(hash) as a description to signify that I am testing instance methods of the object.

When I test features related to object classes, I prefix the description with a `.`
(dot) to signify that I am testing class methods.

I am also creating the article for testing at the top of the describe block, so
it's available for all tests inside the block using the `let` method of RSpec:

```
describe "#validations" do
  let(:article)  { build(:article) }

  ...

end
```

Here's the full code example:

```
# spec/models/article_spec.rb

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
```
