## demon.gemspec
#

Gem::Specification::new do |spec|
  spec.name = "demon"
  spec.version = "0.0.666"
  spec.platform = Gem::Platform::RUBY
  spec.summary = "demon"
  spec.description = "description: demon kicks the ass"

  spec.files =
["README.md",
 "Rakefile",
 "a.rb",
 "a.rb.demon",
 "a.rb.demon/cmdline",
 "a.rb.demon/lock",
 "a.rb.demon/log",
 "a.rb.demon/pid",
 "a.rb.demon/stderr",
 "a.rb.demon/stdin",
 "a.rb.demon/stdout",
 "b.rb",
 "background.rb",
 "cmdline",
 "lib",
 "lib/demon.rb",
 "lock",
 "log",
 "pid",
 "stderr",
 "stdin",
 "stdout"]

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
