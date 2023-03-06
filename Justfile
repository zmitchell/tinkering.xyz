_default:
    @just --list

# Check internal and external links
check:
  @zola check --drafts

# Bring up the server, showing drafts as well
work:
  @zola serve --drafts

# Publish `master` to the drafts site
draft:
  @git push origin master:drafts

# Publish `master` to the production site
publish:
  @git push origin master:publish