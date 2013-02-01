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
    shared = {}

A Journo site has a layout file, stored in `layout.html`. To render a post, we
take its raw **source**, treat it as both an Underscore template (for HTML
generation) and as Markdown (for formatting), and insert it into the layout
as `content`.

    Journo.render = (post, source) ->
      catchErrors ->
        source or= fs.readFileSync postPath post
        shared.layout or= _.template(fs.readFileSync('layout.html').toString())
        variables = {_, fs, path, folderContents, mapLink, postName, post: path.basename(post), posts: sortedPosts(), manifest: shared.manifest}
        markdown  = _.template(source.toString()) variables
        title     = postTitle markdown
        content   = marked.parser marked.lexer markdown
        shared.layout _.extend variables, {title, content}


Publish to Flat Files
---------------------

A blog is a folder on your hard drive. Within the blog, you have a `posts`
folder for blog posts, a `public` folder for static content, a `layout.html`
file, and a `journo.json` file for configuration. During a `build`, a static
version of the site is rendered into the `site` folder.

    fs = require 'fs'
    path = require 'path'
    {ncp} = require 'ncp'

    Journo.publish = ->
      FTPClient = require 'ftp'
      shared.ftp = new FTPClient
      Journo.build()
      todo = loadManifest()
      shared.ftp.on 'ready', ->
        Journo.publishPost post for post in todo.puts
        Journo.unpublishPost post for post in todo.deletes
      shared.ftp.connect shared.config.ftp
      yes

In order to `build` the blog, we render all of the posts out as HTML on disk.

    Journo.build = ->
      loadConfig()
      loadManifest()
      fs.mkdirSync('site') unless fs.existsSync('site')
      ncp 'public', 'site', (err) ->
        throw err if err
      for post in folderContents('posts')
        html = Journo.render post
        file = htmlPath post
        fs.mkdirSync path.dirname(file) unless fs.existsSync path.dirname(file)
        fs.writeFileSync file, html
      fs.writeFileSync "site/feed.rss", Journo.feed()

The `config.json` configuration file is where you keep the nitty gritty details,
like how to connect to your FTP server. The settings are: `host`, `port`,
`secure`, `user`, and `password`.

    loadConfig = ->
      return if shared.config
      try
        shared.config = JSON.parse fs.readFileSync 'config.json'
      catch err
        fatal "Unable to read config.json"
      shared.siteUrl = shared.config.url.replace(/\/$/, '')


Publish Via FTP
---------------

    Journo.FTP = {}

To publish a post, we render it and FTP it up.

    Journo.FTP.publishPost = (post) ->
      fs.readFile postPath(post), (err, content) ->
        shared.ftp.put new Buffer(Journo.render(post, content)), post, (err) ->
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
      s3 or= knox.createClient shared.config.s3

To publish a post, we render it and `PUT` it to S3.

    Journo.S3.publishPost = (post) ->
      client = Journo.S3.connect()
      throw 'content TK'

      request = client.put path.join(shared.config.s3.path, post),
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

    loadManifest = ->
      shared.manifest = if fs.existsSync manifestPath
        JSON.parse fs.readFileSync manifestPath
      else
        {}
      todo = compareManifest()
      writeManifest()
      todo

    writeManifest = ->
      fs.writeFileSync manifestPath, JSON.stringify shared.manifest

We update the manifest by looping through every post and every entry in the
existing manifest, and looking for differences. Return a list of the posts
that need to be `PUT` to the server, and the posts that should be `DELETE`d.

    compareManifest = ->
      posts = folderContents 'posts'
      puts = []
      deletes = []
      for file, meta of shared.manifest when file not in posts
        deletes.push file
        delete shared.manifest[file]
      for file in posts
        stat = fs.statSync "posts/#{file}"
        entry = shared.manifest[file]
        if not entry or entry.mtime isnt stat.mtime
          entry or= {pubtime: new Date}
          entry.mtime = stat.mtime
          content = fs.readFileSync("posts/#{file}").toString()
          entry.title = postTitle content
          puts.push file
          shared.manifest[file] = entry
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
      config = shared.config

      feed = new RSS
        title: config.title
        description: config.description
        feed_url: "#{shared.siteUrl}/rss.xml"
        site_url: shared.siteUrl
        author: config.author

      for post in sortedPosts()[0...20]
        content = fs.readFileSync(postPath post).toString()
        lexed = marked.lexer content
        title = postTitle content
        description = _.find(lexed, (token) -> token.type is 'paragraph')?.text

        feed.item
          title: title
          description: description
          url: postUrl post
          date: shared.manifest[post].pubtime

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
      loadConfig()
      loadManifest()
      server = http.createServer (req, res) ->
        rawPath = url.parse(req.url).pathname.replace(/^\//, '') or 'index'
        if rawPath is 'feed.rss'
          res.writeHead 200, 'Content-Type': mime.lookup('.rss')
          res.end Journo.feed()
        else
          publicPath = "public/" + rawPath
          fs.exists publicPath, (exists) ->
            if exists
              res.writeHead 200, 'Content-Type': mime.lookup(publicPath)
              fs.createReadStream(publicPath).pipe res
            else
              post = "posts/#{rawPath}.md"
              fs.exists post, (exists) ->
                if exists
                  fs.readFile post, (err, content) ->
                    res.writeHead 200, 'Content-Type': 'text/html'
                    res.end Journo.render post, content
                else
                  res.writeHead 404
                  res.end '404 Not Found'

      server.listen 1234
      console.log "Journo is previewing at http://localhost:1234"


Work Without JavaScript, But Default to a Fluid JavaScript-Enabled UI
---------------------------------------------------------------------

The best way to handle this bit seems to be entirely on the client-side. For
example, when rendering a JavaScript slideshow of photographs, instead of
having the server spit out the slideshow code, simply have the blog detect
the list of images during page load and move them into a slideshow right then
and there -- using `alt` attributes for captions, for example.

Since the blog is public, it's nice if search engines can see all of the pieces
as well as readers.


Finally, Putting it all Together. Run Journo From the Terminal
--------------------------------------------------------------

    Journo.run = ->
      args = process.argv.slice 2
      command = args[0] or 'preview'
      if Journo[command]
        do Journo[command]
      else
        console.error "Journo doesn't know how to '#{command}'"


Miscellaneous Bits and Utilities
--------------------------------

For convenience, keep functions handy for finding the local file path to a post,
and the URL for a post on the server.

    postPath = (post) -> "posts/#{post}"

    htmlPath = (post) ->
      name = postName post
      if name is 'index'
        'site/index.html'
      else
        "site/#{name}/index.html"

    postName = (post) -> path.basename post, '.md'

    postUrl = (post) -> "#{shared.siteUrl}/#{postName(post)}"

    postTitle = (content) ->
      _.find(marked.lexer(content), (token) -> token.type is 'heading')?.text

    folderContents = (folder) ->
      fs.readdirSync(folder).filter (f) -> f.charAt(0) isnt '.'

    sortedPosts = ->
      _.sortBy _.without(_.keys(shared.manifest), 'index.md'), (post) ->
        shared.manifest[post].pubtime

Quick function to creating a link to a Google Map.

    mapLink = (place, additional = '', zoom = 15) ->
      query = encodeURIComponent("#{place}, #{additional}")
      "<a href=\"https://maps.google.com/maps?q=#{query}&t=h&z=#{zoom}\">#{place}</a>"

Convenience function for catching errors (keeping the preview server from
crashing while testing code), and printing them out.

    catchErrors = (func) ->
      try
        func()
      catch err
        console.error err.stack
        "<pre>#{err.stack}</pre>"

And then for errors that you want the app to die on -- things that would break
the site build.

    fatal = (message) ->
      console.error message
      process.exit 1




