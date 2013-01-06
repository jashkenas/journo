Journo
------

    Journo = module.exports = {}

Journo is a blogging program, with a few basic goals. To wit:

* Write in Markdown.

* Publish to flat files.

* Publish via (S)FTP or S3.

* Maintain its own manifest file (what's published and what isn't, pub dates).

* Retina ready.

* Can syntax highlight code and handle large photo slideshows.

* Can handle minimal metadata (photos have captions, posts have titles).

* Publishes a feed.

* Works without JavaScript, but has a fluid JavaScript-enabled UI.

... let's go through these one at a time:


Write in Markdown
=================

We'll use the excellent `marked` module to compile Markdown into HTML.

    marked = require 'marked'

    Journo.markdown = (source) ->
      marked.parser marked.lexer source


Publish to Flat Files
=====================

A blog is a folder on your hard drive. Within the blog, you have a `posts`
folder for blog posts, and a `journo.json` file for configuration.

    fs = require 'fs'
    FTPClient = require 'ftp'
    ftp = new FTPClient

    configuration = manifest = null

    Journo.publish = ->
      configuration = loadConfiguration()
      manifest = loadManifest()
      posts = fs.readdirSync 'posts'
      todo = compareManifest posts
      ftp.connect configuration
      Journo.publishPost post for post in todo.puts
      Journo.unpublishPost post for post in todo.deletes
      ftp.end()
      writeManifest()
      yes

The `journo.json` configuration file is where you keep the nitty gritty details,
like how to connect to your FTP server. The settings are: `host`, `port`,
`secure`, `user`, and `password`.

    loadConfiguration = ->
      JSON.parse fs.readFileSync 'journo.json'


Publish Via FTP or S3
=====================

To publish a post, we render it and FTP it up.

    Journo.publishPost = (post) ->
      throw 'TK'

To unpublish a post, we delete it via FTP.

    Journo.unpublishPost = (post) ->
      throw 'TK'


Maintains its own Manifest File
==============================

The "manifest" is where Journo keeps track of metadata (the publication date
and last recorded modified time) about each post.

    manifestPath = 'journo-manifest.json'

    emptyManifest = posts: {}, published: null

    loadManifest = ->
      if fs.existsSync manifestPath
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
============


Can Syntax Highlight Code
=========================


Can Create Photo Slideshows
===========================


Can Handle Minimal Metadata
===========================


Publishes a Feed
================


Works Without JavaScript, But has a Fluid JavaScript-Enabled UI
===============================================================




