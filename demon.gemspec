## demon.gemspec
#

Gem::Specification::new do |spec|
  spec.name = "demon"
  spec.version = "0.0.666"
  spec.platform = Gem::Platform::RUBY
  spec.summary = "demon"
  spec.description = "demon.rb - the ruby daemon library you've been waiting for"

  spec.files =
["README.md", "Rakefile", "demon.gemspec", "lib", "lib/demon.rb"]

  spec.executables = []
  
  spec.require_path = "lib"

  spec.test_files = nil

### spec.add_dependency 'lib', '>= version'
#### spec.add_dependency 'map'

  spec.extensions.push(*[])

  spec.rubyforge_project = "codeforpeople"
  spec.author = "Ara T. Howard"
  spec.email = "ara.t.howard@gmail.com"
  spec.homepage = "https://github.com/ahoward/demon"
end
