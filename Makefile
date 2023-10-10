# Targets that don't produce files
.PHONY: deploy-all deploy-blog deploy-profile init-profile-remote init-profile clean init commit rebase

# Default target
all: $(BLOG) blog_index profile

# Clean target to remove temporary files
clean:
	@(rm -fr $(DIST_PATH) 2>/dev/null || true) && mkdir -p {$(PROFILE_DIST),$(BLOG_DIST)}

# Print macro variables for debugging
print-%:
	@echo $*=$($*)

########### VARIABLES #############

# Directory structure
BLOG_SRC = ./blog
DIST_PATH = ./dist
BLOG_DIST = ./dist/blog
PROFILE_DIST = ./dist/profile
PROFILE_PREFIX = 'dist/profile'
PROFILE_REMOTE = 'gh-profile'
PROFILE_REMOTE_URL = 'https://github.com/$(GH_USER)/$(GH_USER).git'

# Pandoc arguments macros
PANDOC_HTML_ROOT_ARG = --template ./templates/root.html
PANDOC_HTML_FOOTER_ARG = --include-after-body=./templates/footer.html
PANDOC_HTML_THANKS_AND_COOKIE_ARGS = --include-in-header=./templates/fortune-cookie-component.html \
		--include-after-body=./templates/thank-you-note.html
PANDOC_HTML_BLOG_ARGS = $(PANDOC_HTML_ROOT_ARG) \
		--toc \
		--section-divs \
		--lua-filter=./pandoc_filters/permalinks/permalinks.lua \
		$(PANDOC_HTML_THANKS_AND_COOKIE_ARGS) \
		$(PANDOC_HTML_FOOTER_ARG)
PANDOC_HTML_PROFILE_ARGS = $(PANDOC_HTML_ROOT_ARG) \
		--section-divs \
		$(PANDOC_HTML_THANKS_AND_COOKIE_ARGS) \
		$(PANDOC_HTML_FOOTER_ARG)

# Blog posts macros
BLOG_POSTS_WIP_SRC := $(wildcard $(BLOG_SRC)/*/WIP_*)
BLOG_POSTS_SRC := $(filter-out $(BLOG_POSTS_WIP_SRC), $(wildcard $(BLOG_SRC)/*/*.md) \
									$(wildcard $(BLOG_SRC)/*/*.org) \
									$(wildcard $(BLOG_SRC)/*/*.tex))
BLOG := $(patsubst $(BLOG_SRC)/%.org,$(BLOG_DIST)/%.html, \
					$(patsubst $(BLOG_SRC)/%.md,$(BLOG_DIST)/%.html, \
					$(patsubst $(BLOG_SRC)/%.tex,$(BLOG_DIST)/%.html, \
						$(BLOG_POSTS_SRC))))

########### BLOG #############

# Generate HTML from Markdown source
$(BLOG_DIST)/%.html: $(BLOG_SRC)/%.md
	@mkdir -p $(@D)
	@pandoc -i $< -t html -o $@ $(PANDOC_HTML_BLOG_ARGS)

# Generate HTML from Org source
$(BLOG_DIST)/%.html: $(BLOG_SRC)/%.org
	@mkdir -p $(@D)
	@pandoc -f org -i $< -t html -o $@ $(PANDOC_HTML_BLOG_ARGS)

# Generate HTML from LaTeX source
$(BLOG_DIST)/%.html: $(BLOG_SRC)/%.tex
	@mkdir -p $(@D)
	@pandoc -f latex -i $< -t html -o $@ $(PANDOC_HTML_BLOG_ARGS)

# Remove index.html from the blog directory
remove_index:
	@rm $(BLOG_DIST)/index.html 2>/dev/null || true

# Generate index.html files for blog sections
blog_index: $(BLOG) remove_index
	@$(foreach series, $(wildcard $(BLOG_DIST)/*), \
		ls $(series) \
			| grep -v index.html \
			| ./scripts/filename2index.py \
			| pandoc -t html -o $(series)/index.html \
				--metadata title:"$(shell echo '$(series)' | ./scripts/directory2title.py)" \
				$(PANDOC_HTML_ROOT_ARG) \
				$(PANDOC_HTML_FOOTER_ARG);)
	@ls $(BLOG_DIST) \
	  	| grep -v index.html \
	  	| ./scripts/directory2index.py \
	  	| pandoc -t html -o $(BLOG_DIST)/index.html \
				--metadata title:"$(GH_USER)/blog" \
				$(PANDOC_HTML_ROOT_ARG) \
				$(PANDOC_HTML_FOOTER_ARG)

########### PROFILE #############

# Generate profile from Org or Markdown source
profile: $(wildcard ./README.org) $(wildcard ./README.md)
	@[[ -f ./README.org ]] && bash -c 'cat ./README.org \
		| tee >(pandoc -f org -t gfm -o $(PROFILE_DIST)/README.md) \
		| pandoc -f org -t html -o ./index.html $(PANDOC_HTML_PROFILE_ARGS)' \
			|| true
	@[[ -f ./README.md ]] && bash -c 'cat ./README.md \
		| tee >(pandoc -t gfm -o $(PROFILE_DIST)/README.md) \
		| pandoc -t html -o ./index.html $(PANDOC_HTML_PROFILE_ARGS)' \
			|| true

########### DEPLOY #############

# Commit changes if there are any
commit:
ifneq ($(shell git status --short),)
	@git checkout master
	@git add .
	@git commit
endif

# Rebase the repository
rebase:
	@git checkout master \
		&& git fetch --all \
		&& git pull --rebase origin master \
    --recurse-submodules

# Deploy profile subtree
deploy-profile:
	@git checkout master \
		&& git diff --quiet \
		&& git subtree split --prefix $(PROFILE_PREFIX) -b gh-profile \
		&& git push -f $(PROFILE_REMOTE) gh-profile:master \
		&& git branch -D gh-profile

# Push changes to the blog repository
deploy-blog:
	@git checkout master \
		&& git diff --quiet \
		&& git push origin master --force

# Deploy all targets, commit changes, and rebase the repository
deploy-all: commit rebase deploy-blog deploy-profile

# Deploy the blog and profile quickly
deploy-quick: deploy-blog deploy-profile

########### INIT #############

# Initialize the profile remote repository
init-profile-remote:
	@(git remote rm $(PROFILE_REMOTE) 2>/dev/null \
		&& git remote add $(PROFILE_REMOTE) $(PROFILE_REMOTE_URL)) \
		|| git remote add $(PROFILE_REMOTE) $(PROFILE_REMOTE_URL)

# Initialize the profile subtree
init-profile: init-profile-remote
	@[[ -d $(PROFILE_DIST) ]] \
		|| git subtree add --prefix $(PROFILE_DIST) $(PROFILE_REMOTE) master -m '🤖 add profile subtree'

# Initialize the project
init: clean init-profile-remote init-profile

########### END #############
