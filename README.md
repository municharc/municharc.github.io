## Adding a post

Add a new post by creating a new markdown file under `_posts`, with the appropriate timestamp in the filename. Place the images needed the post under `images/`. 

## Develop

Website template is built with [Jekyll](http://jekyllrb.com/) version 3.3.1, but should support newer versions as well.

Install the dependencies with [Bundler](http://bundler.io/):

~~~bash
$ bundle install
~~~

If you are on linux and the installation fails, you can try upgrading the gems, for example with this Gemfile:
```bash
source 'https://rubygems.org'

gem 'jekyll', '~> 4.4'

group :jekyll_plugins do
  gem 'jekyll-seo-tag'
  gem 'jekyll-sitemap'
end

gem "webrick", "~> 1.9"
gem 'sass-embedded', '~> 1.97'

gem "logger", "~> 1.7"

gem "erb", "~> 6.0"
```

Run `jekyll` commands through Bundler to ensure you're using the right versions:

~~~bash
$ bundle exec jekyll serve
~~~

`index.html` is the main webpage, `events.html` is the webpage with the events calendar and past events posts. `_layouts` and `_sass` contain the template layout and css files resp.

## Credit

Based on Cause jekyll [template](https://github.com/CloudCannon/cause-jekyll-template) by CloudCannon.
