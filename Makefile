all: runserver

deploy:
	jekyll build

runserver:
	jekyll serve -w -H 0.0.0.0 -P 8081
