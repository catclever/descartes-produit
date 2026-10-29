# frozen_string_literal: true

require_relative "lib/descartes/hub/version"

Gem::Specification.new do |spec|
  spec.name = "descartes-produit"
  spec.version = Descartes::Hub::VERSION
  spec.authors = ["Kael.Cai"]
  spec.email = ["saint.archangel.satan@gmail.com"]

  spec.summary = "Distributed Hub service and server for Descartes Agent framework."
  spec.description = "Descartes Hub coordinates distributed agent sessions, decoupling reasoning in the cloud from local tool execution at the edge."
  spec.homepage = "https://github.com/catclever/descartes-produit"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/catclever/descartes-produit"

  spec.files = Dir.glob("{bin,lib}/**/*") + %w[README.md Dockerfile compose.yaml]
  spec.bindir = "bin"
  spec.executables = ["descartes-produit"]
  spec.require_paths = ["lib"]

  spec.add_dependency "descartes"
  spec.add_dependency "rack"
  spec.add_dependency "puma"
  spec.add_dependency "faye-websocket"
  spec.add_dependency "eventmachine"
end
