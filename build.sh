#!/usr/bin/env bash

getBlogSlug(){
	echo "$1" | sed 's/^content\///' | sed 's/.md$/.html/' | sed -E 's/[0-9]+-/\/blog\//'
}

blog(){
	find content/ -type f -name '*.md' | while read file; do
		newFileName=$(getBlogSlug "$file")
		mkdir -p "public_html/${newFileName%/*}"
		pandoc --template=templates/blog.html -f markdown -t html5 "$file" > "public_html/$newFileName"
	done
}

makeIntro(){
	local file="$1"
	local info="$(sed -n '/---/,/---/p' "$file" | sed '/^---$/d')"
	local slug=$(getBlogSlug "$file")
	local date="$(echo "$info" | yq -r .date)"
	local tags="$(echo "$info" | yq -r 'if ( .tags | type ) == "array" then .tags else [ .tags ] end | join("\n")' | awk '{print "<li>" $0 "</li>"}' )"
	local title="$(echo "$info" | yq -r .title)"
	local description="$(echo "$info" | yq -r .description)"
	echo "<article>
		<h2><a href='$slug'>$title</a></h2>
		<div class="article-details">
			<div class="date">
				$date
			</div>
		</div>
		<p>$description</p>
	</article>"
}

index(){
	(
		sed -n '1,/#CONTENT#/p' templates/index.html | head -n -1
		find content/ -type f -name '*.md' | sort -r | head -n 3 | while read file; do
			makeIntro "$file"
		done
		sed -n '/#CONTENT#/,/#TAGLIST#/p' templates/index.html | sed '1d' | head -n -1
		cat generated-template-parts/tagList.html
		sed -n '/#TAGLIST#/,$p' templates/index.html | sed '1d'
	) > public_html/index.html
}

tagIndex(){
	local tag="$1"
	sed -n '1,/#CONTENT#/p' templates/index.html | head -n -1
	cat "$1" | sort -r | while read file; do
		makeIntro "$file"
	done
	sed -n '/#CONTENT#/,/#TAGLIST#/p' templates/index.html | sed '1d' | head -n -1
	cat generated-template-parts/tagList.html
	sed -n '/#TAGLIST#/,$p' templates/index.html | sed '1d'
}


html_tag_list(){
	if [ -d "tmp/tag" ]; then
		echo "<ul class='taglist'>"
			wc -l tmp/tag/* | head -n -1 | sort -nr | while read line; do
				local link=$(echo "$line" | awk '{print $2 ".html"}' | sed 's/^tmp//' | tr '[A-Z]' '[a-z]' | tr ' ' '-')
				local name=$(echo "$line" | sed 's/tmp\/tag\///' | awk '{print $2 " (" $1 ")"}')
				echo "<li><a href='$link'>$name</a></li>"
			done
		echo "</ul>"
	else
		echo "Need to generate the taglist" > /dev/stderr
	fi
}

tags(){

	# Make sure we have a new folder to work from
	rm -rf tmp/tag 2> /dev/null
	mkdir -p tmp/tag 2> /dev/null
	mkdir -p generated-template-parts 2> /dev/null
	rm generated-template-parts/tagList.html 2> /dev/null
	rm -rf public_html/tag 2> /dev/null
	mkdir -p public_html/tag 2> /dev/null

	# Loops through each blog and puts it in tag lists
	find content/ -type f -name '*.md' | while read file; do
		sed -n '/---/,/---/p' "$file" | sed '/^---$/d' | yq -r 'if ( .tags | type ) == "array" then .tags else [ .tags ] end | join("\n")' | while read tag; do
			echo "$file" >> tmp/tag/"$tag"
		done
	done
	# We should now have a folder with a text file for each tag containing each blog

	# This is included by the pandoc template
	html_tag_list > generated-template-parts/tagList.html

	find tmp/tag/ -type f | while read tag; do
	filename="$(echo $tag | sed 's/^tmp//' | tr '[A-Z]' '[a-z]').html"
		tagIndex "$tag" > "public_html/$filename"
	done

}

case "$1" in
	index) index ;;
	blog) blog ;;
	tags) tags ;;
	all) tags && blog && index ;;
esac
