profile_path = 'dist/profile'
profile_remote = 'gh-profile'
profile_remote_url = 'https://github.com/$(GH_USER)/$(GH_USER).git)'
inputs := $(wildcard ./blog/*.md)
outputs := $(patsubst ./blog/%.md,./dist/blog/%.html,$(inputs))

all: $(outputs) index profile

clean:
	(rm -fr ./dist || true) && mkdir -p ./dist/{blog,profile}

./dist/blog/%.html : ./blog/%.md
	pandoc -f gfm -i $< -t html -o $@

index: $(outputs)
	ls ./blog | ./scripts/filename2index.sh > ./dist/blog/Index.md \
		&& pandoc -f gfm -i ./dist/blog/Index.md -t html -o ./index.html

readme: ./README.md

profile: $(outputs) index readme
	cat ./README.md > ./dist/profile/README.md \
		&& cat ./dist/blog/Index.md >> ./dist/profile/README.md

##################################################################################

init-profile-remote:
	(git remote rm $(profile_remote) 2>/dev/null \
		&& git remote add $(profile_remote) $(profile_remote_url) \
		|| git remote add $(profile_remote) $(profile_remote_url)

init-profile: init-profile-remote
	[[ -d $(profile_path) ]] \
		|| git subtree add --prefix $(profile_path) $(profile_remote) master --squash -m '🤖 add profile subtree'

pull-profile: init-profile
	git subtree pull --prefix $(profile_path) $(profile_remote) master --squash -m '🤖 pull profile subtree'

push-profile: pull-profile
	git subtree push --prefix $(profile_path) $(profile_remote) master --squash

.PHONY: all pull-profile push-profile init-profile init-profile-remote clean