<div class="index-page">

  <%
    _.each(posts.reverse(), function(file) {
      var post = postName(file);
      var data = manifest[file];
      if (post == 'index') return;
  %>
    <a class="post-item" href="/<%= post %>/">
      <%= data.title %>
    </a>
  <% }); %>

</div>
