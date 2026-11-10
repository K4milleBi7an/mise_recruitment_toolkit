source "https://rubygems.org"

ruby ">= 3.2"

gem "sinatra", "~> 4.0"   # routing + ERB views
gem "puma"                # web server
gem "rackup"              # `bundle exec rackup`
gem "erubi"               # auto-escaping ERB
gem "csv"                 # no longer a default gem from Ruby 3.4
gem "tzinfo"              # time zone maths
gem "tzinfo-data", platforms: %i[windows jruby]

group :test do
  gem "minitest"
  gem "rack-test"
end
