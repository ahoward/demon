### NAME

  demon.rb - the ruby daemon library you've been waiting for

### SYNOPSIS

  a small, flexible, powerful ruby daemon library

### DESCRIPTION

  demon.rb aims to make it simple to construct extremely well behaved daemon
  programs in no time.

  it supports both a DSL and object oriented interface to sound unix daemon
  code.  unlike some daemon libraries, it makes zero assumptions about how you
  want to organize your code - although some sane defaults exists to help you
  along if you don't what to think about this at all.

### INSTALL

  gem 'demon'

### USAGE

# simple usage is simple

````ruby

#! /usr/bin/env ruby

# file: a.rb


Demon do

  loop do

    stuff_as_a_daemon

  end

end


````

````bash

  ./a.rb help 

````

````yaml

  ---
  start: start in daemon mode
  run: run in the foreground, but otherwise like a daemon
  stop: stop any currently running daemon
  restart: restart any currently running daemon, or start a new one
  pid: print the pid of the running daemon, iff any
  ping: ensure a daemon is running, start one iff not
  signal: hit the daemon, if any, with SIGUSR2
  tail: tail -F all auxillary files (lock files, logs, etc)
  fuser: report the fuser of any auxillary files (lock files, logs, etc)
  log: display the location of the log file
  root: display the location of the root daemon dir (lock files, logs, etc)
  modes: print all modes, even those without "help"
  help: this message


````

a few things to notice about the above daemon:

* daemons are *expected* to run for a long time.  demon.rb will run the supplied block over and over (aka. it is an implied loop)
* if the supplied block blows up the error will be logged, and the block retried.  we assume you mean to keep your daemon up.
* the actual script being run must be know to demon.rb.  you can let it know by passing a block, or supplying __FILE__ as the first arugment

````ruby

Demon __FILE__ do

  # stuff

end

````
