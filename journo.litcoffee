Journo
======

    Journo = module.exports = {}

Journo is a blogging program, with a few basic goals. To wit:

* Write in Markdown.

* Publish to flat files.

* Publish via (S)FTP or S3.

* Maintain a manifest file (what's published and what isn't, pub dates).

* Retina ready.

* Syntax highlight code and handle large photo slideshows.

* Handle minimal metadata (photos have captions, posts have titles).

* Publish a feed.

* Quickly bootstrap a new blog.

* Preview via a local server.

* Work without JavaScript, but default to a fluid JavaScript-enabled UI.

... let's go through these one at a time:


Write in Markdown
-----------------

We'll use the excellent `marked` module to compile Markdown into HTML, and
Underscore for many of its goodies later on.

    marked = require 'marked'
    _ = require 'underscore'
    skeleton = null

    Journo.render = (source) ->
      skeleton or= _.template(fs.readFileSync('skeleton.html').toString())
      markdown = source = _.template(source.toString())({})
      lexed = marked.lexer markdown
      title = _.find(lexed, (token) -> token.type is 'heading')?.text
      content = marked.parser lexed
      skeleton {title, content}


Publish to Flat Files
---------------------

A blog is a folder on your hard drive. Within the blog, you have a `posts`
folder for blog posts, and a `journo.json` file for configuration.

    fs = require 'fs'
    path = require 'path'
    {ncp} = require 'ncp'
    ftp = config = siteUrl = manifest = null

    Journo.publish = ->
      FTPClient = require 'ftp'
      ftp = new FTPClient
      Journo.build()
      todo = compareManifest allPosts()
      ftp.on 'ready', ->
        Journo.publishPost post for post in todo.puts
        Journo.unpublishPost post for post in todo.deletes
      ftp.connect config.ftp
      writeManifest()
      yes

In order to `build` the blog, we render all of the posts out as HTML on disk.

    Journo.build = ->
      loadConfig()
      loadManifest()
      fs.mkdirSync('site') unless fs.existsSync('site')
      ncp 'public', 'site', (err) ->
        throw err if err
      for post in allPosts()
        markdown = fs.readFileSync postPath post
        html = Journo.render markdown
        name = path.basename(post, '.md')
        dir = "site/#{name}"
        fs.mkdirSync dir unless fs.existsSync dir
        fs.writeFileSync "#{dir}/index.html", html

The `config.json` configuration file is where you keep the nitty gritty details,
like how to connect to your FTP server. The settings are: `host`, `port`,
`secure`, `user`, and `password`.

    loadConfig = ->
      return if config
      try
        config = JSON.parse fs.readFileSync 'config.json'
      catch err
        fatal "Unable to read config.json"
      siteUrl = config.url.replace(/\/$/, '')

For convenience, keep functions handy for finding the local file path to a post,
and the URL for a post on the server.

    postPath = (post) -> "posts/#{post}"

    postUrl = (post) -> "#{siteUrl}/#{post}"

    allPosts = -> fs.readdirSync 'posts'

Quick helper for any fatal errors that might be encountered during a build.

    fatal = (message) ->
      console.error message
      process.exit 1


Publish Via FTP
---------------

    Journo.FTP = {}

To publish a post, we render it and FTP it up.

    Journo.FTP.publishPost = (post) ->
      fs.readFile postPath(post), (err, content) ->
        ftp.put new Buffer(Journo.render(content)), post, (err) ->
          throw err if err

To unpublish a post, we delete it via FTP.

    Journo.FTP.unpublishPost = (post) ->
      throw 'TK'


Publish Via S3
--------------

We'll use the `knox` library to connect to S3.

    Journo.S3 = {}
    knox = require 'knox'
    s3 = null

    Journo.S3.connect = ->
      loadConfig()
      s3 or= knox.createClient config.s3

To publish a post, we render it and `PUT` it to S3.

    Journo.S3.publishPost = (post) ->
      client = Journo.S3.connect()
      throw 'content TK'

      request = client.put path.join(config.s3.path, post),
        'Content-Length': content.length
        'Content-Type': 'text/html'
        'x-amz-acl': 'public-read'

      request.on 'response', (response) ->
        if response.statusCode is 200
          console.log "PUT #{post}"

      request.end content


Maintain a Manifest File
------------------------

The "manifest" is where Journo keeps track of metadata (the publication date
and last recorded modified time) about each post.

    manifestPath = 'journo-manifest.json'

    emptyManifest = posts: {}, published: null

    loadManifest = ->
      manifest = if fs.existsSync manifestPath
        JSON.parse fs.readFileSync manifestPath
      else
        emptyManifest

    writeManifest = ->
      fs.writeFileSync manifestPath, JSON.stringify manifest

We update the manifest by looping through every post and every entry in the
existing manifest, and looking for differences. Return a list of the posts
that need to be `PUT` to the server, and the posts that should be `DELETE`d.

    compareManifest = (posts) ->
      puts = []
      deletes = []
      for file, meta of manifest when file not in posts
        deletes.push file
      for file in posts
        stat = fs.statSync "posts/#{file}"
        entry = manifest[file]
        if not entry or entry.mtime isnt stat.mtime
          entry or= {pubtime: new Date}
          entry.mtime = stat.mtime
          puts.push file
          manifest[file] = entry
      {puts, deletes}


Retina Ready
------------


Syntax Highlight Code
---------------------

    {Highlight} = require 'highlight'

    marked.setOptions
      highlight: (code, lang) ->
        Highlight code


Create Photo Slideshows
-----------------------


Handle Minimal Metadata
-----------------------


Publish a Feed
--------------

    Journo.feed = ->
      RSS = require 'rss'
      loadConfig()

      feed = new RSS
        title: config.title
        description: config.description
        feed_url: "#{siteUrl}/rss.xml"
        site_url: siteUrl
        author: config.author

      sorted = _.sortBy _.keys(manifest), (post) -> manifest[post].pubtime

      for post in sorted[0...20]
        content = fs.readFileSync postPath post
        lexed = marked.lexer content
        title = _.find lexed, (token) -> token.type is 'heading'
        description = _.find lexed, (token) -> token.type is 'paragraph'

        feed.item
          title: title
          description: description
          url: postUrl post
          date: manifest[post].pubtime

      feed.xml()


Quickly Bootstrap a New Blog
----------------------------

    Journo.init = ->
      here = fs.realpathSync '.'
      if fs.existsSync 'posts'
        return console.error "A blog already exists in #{here}"
      bootstrap = path.join(__dirname, 'bootstrap')
      ncp bootstrap, '.', (err) ->
        return console.error(err) if err
        console.log "Initialized new blog in #{here}"



Preview via a Local Server
--------------------------

    Journo.preview = ->
      http = require 'http'
      mime = require 'mime'
      url = require 'url'
      util = require 'util'
      server = http.createServer (req, res) ->
        path = url.parse(req.url).pathname.replace /^\//, ''
        publicPath = "public/#{path}"
        fs.exists publicPath, (exists) ->
          if exists
            res.writeHead 200, 'Content-Type': mime.lookup(publicPath)
            fs.createReadStream(publicPath).pipe res
          else
            post = "posts/#{path}.md"
            fs.exists post, (exists) ->
              if exists
                fs.readFile post, (err, content) ->
                  res.writeHead 200, 'Content-Type': 'text/html'
                  res.end Journo.render content
              else
                res.writeHead 404
                res.end '404 Not Found'

      server.listen 1234
      console.log "Journo is previewing at http://localhost:1234"


Work Without JavaScript, But Default to a Fluid JavaScript-Enabled UI
---------------------------------------------------------------------


Finally, Putting it all Together. Run Journo From the Terminal
--------------------------------------------------------------

    Journo.run = ->
      args = process.argv.slice 2
      command = args[0] or 'preview'
      if Journo[command]
        do Journo[command]
      else
        console.error "Journo doesn't know how to '#{command}'"




