# frozen_string_literal: true

source "https://rubygems.org"

gemspec

if ENV["CI"] || !Dir.exist?(File.expand_path("../descartes", __dir__))
  gem "descartes", github: "catclever/descartes"
else
  gem "descartes", path: "../descartes"
end

if ENV["CI"] || !Dir.exist?(File.expand_path("../llm_json", __dir__))
  gem "llm_json", github: "catclever/llm_json"
  gem "ruby_llm", github: "catclever/ruby_llm"
else
  gem "llm_json", path: "../llm_json"
  gem "ruby_llm", path: "../ruby_llm"
end

gem "rack"
gem "puma"
gem "faye-websocket"
gem "eventmachine"

gem "irb"
gem "rake", "~> 13.0"
gem "rspec", "~> 3.0"
