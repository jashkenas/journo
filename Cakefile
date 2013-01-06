{spawn} = require 'child_process'

task "build", "watch and build the Journo source", ->
  compiler = spawn 'coffee', ['-cw', '.']
  compiler.stdout.on 'data', (data) -> console.log data.toString().trim()
  compiler.stderr.on 'data', (data) -> console.error data.toString().trim()


