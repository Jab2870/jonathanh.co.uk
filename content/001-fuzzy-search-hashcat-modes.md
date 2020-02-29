---
title: Fuzzy Search Hashcat Modes
tags:
  - Pentesting
  - FZF
  - Linux
description: Hashcat is an amazing tool for cracking hashes but the syntax leaves a bit to be desired. This article explains one way to improve the experience of selecting modes by overriding ZSH's built in tab-completion using FZF.
date: 2020-02-24
---


There is little doubt that [Hashcat](https://hashcat.net/hashcat/) is an amazing tool for cracking hashes. Unfortunately, the command syntax leaves quite a lot to be desired. My focus today is on Hashcat's modes. Here is a snippet from the help page:

```
 - [ Hash modes ] -
 
       # | Name                                             | Category
   ======+==================================================+======================================
     900 | MD4                                              | Raw Hash
       0 | MD5                                              | Raw Hash
    5100 | Half MD5                                         | Raw Hash
     100 | SHA1                                             | Raw Hash
    1300 | SHA2-224                                         | Raw Hash
    1400 | SHA2-256                                         | Raw Hash
   10800 | SHA2-384                                         | Raw Hash
    1700 | SHA2-512                                         | Raw Hash
   17300 | SHA3-224                                         | Raw Hash
   17400 | SHA3-256                                         | Raw Hash
   17500 | SHA3-384                                         | Raw Hash
   17600 | SHA3-512                                         | Raw Hash
   17700 | Keccak-224                                       | Raw Hash
```

I don't know about you, but remembering the hash numbers for more than 2 or 3 of the most common hash types is not something I can do. My old solution was to run `hashcat --example-hashes | less -i` then search for the hash I was looking for. This worked, but still felt inefficient.

Doesn't this look easier:

![FZF with Hash cat Modes](/assets/fuzzy-search-hashcat-modes/hashcat-fzf.gif)

If all you want to do is implement this, simply download the relevant file and source it in either your `.bashrc` or your `.zshrc`.

* [Bash](/assets/fuzzy-search-hashcat-modes/hashcatModeComplete.bash)
* [Zsh](/assets/fuzzy-search-hashcat-modes/hashcatModeComplete.zsh)

You will need to make sure you have [FZF insatlled](https://github.com/junegunn/fzf#installation).

If you're interested in finding out how it works, carry on reading.

## Introducing FZF

[FZF](https://github.com/junegunn/fzf) is a fuzzy finder for the command line. It provides a way of interactively selecting an item from a list.

The most common use case is searching through files or folders but it will search through anything you give it.

It takes its input list (the things to search through) from `stdin`, it then pipes the choice to `stdout`, making it very easy to use with other command line tools like `find`, `awk`, `grep` and, you guessed it, **hashcat**.

## Input list

`FZF` expects each choice to be on its own line. So, we need to get a list of hashcat modes and their names to search through on individual lines.

Hashcat gives us a list of example hashes which include everything we need to get started.

```bash
$ hashcat --example-hashes
MODE: 0
TYPE: MD5
HASH: 8743b52063cd84097a65d1633f5c74f5
PASS: hashcat

MODE: 10
TYPE: md5($pass.$salt)
HASH: 3d83c8e717ff0e7ecfe187f088d69954:343141
PASS: hashcat
...
```

We can use normal command line tools like `awk` to put the parts we are interested in on one line.

The `RS` stands for **record separator**. We are telling awk that an empty line, should be used to delimit each record.

Inside the awk expression, we replace all new lines with tabs, then print the first and second fields.
```bash
$ hashcat --example-hashes | awk -v RS="\n\n" -F "\t" '{gsub("\n","\t",$0); print $1 "\t" $2 }'
MODE: 0         TYPE: MD5
MODE: 10        TYPE: md5($pass.$salt)
MODE: 11        TYPE: Joomla < 2.5.18
MODE: 12        TYPE: PostgreSQL
MODE: 20        TYPE: md5($salt.$pass)
MODE: 21        TYPE: osCommerce, xt:Commerce
MODE: 22        TYPE: Juniper NetScreen/SSG (ScreenOS)
MODE: 23        TYPE: Skype
MODE: 30        TYPE: md5(utf16le($pass).$salt)
MODE: 40        TYPE: md5($salt.utf16le($pass))
...
```

And `sed` to remove the words **MODE** and **TYPE**

```bash
$ hashcat --example-hashes | awk -v RS="\n\n" -F "\t" '{gsub("\n","\t",$0); print $1 "\t" $2 }' | sed 's/MODE: //; s/TYPE: //'
0         MD5
10        md5($pass.$salt)
11        Joomla < 2.5.18
12        PostgreSQL
20        md5($salt.$pass)
21        osCommerce, xt:Commerce
22        Juniper NetScreen/SSG (ScreenOS)
23        Skype
30        md5(utf16le($pass).$salt)
40        md5($salt.utf16le($pass))
...
```

This step could have been done with `awk` as well but, in my tests, `sed` was quicker, even though awk was already being used.

This is now ready to pipe into `fzf`. This should give you a choice of hashes and types you can search through. Once you've chosen, it will print out your choice to `stdout`.

![FZF with Hash cat Modes](/assets/fuzzy-search-hashcat-modes/hashcat-fzf-input-list.gif)

Excellent, you could add an alias now in your `.bashrc` (or equivalent) like this:

```bash
alias hashcatsearch='hashcat --example-hashes | awk -v RS="\n\n" -F "\t" '{gsub("\n","\t",$0); print $1 "\t" $2 }' | sed "s/MODE: //; s/TYPE: //" | fzf'
```

## Making it look nice

FZF also provides a lot of formatting options. Check out `man fzf` for all of them. Below is my preference:

```bash
hashcat --example-hashes | awk -v RS="\n\n" -F "\t" '{gsub("\n","\t",$0); print $1 "\t" $2 "\t" $3}' | sed 's/MODE: //; s/TYPE: //' | fzf -d "\t" --header="Mode Type" --with-nth='1,2' --preview='echo {3}' --preview-window=up:1 --height=40%
```

You will see that it adds an example hash to a preview window at the top, it limits fzf to 40% of the height of the terminal and it adds a header line.

## Tab Completion

This is better than less, but it is still another command. What we really want is to trigger this when we would normally do tab completion. Well, we can. Instructions will vary though, based on your shell. If you're not sure, you are probably running bash although you can check by running

```bash
echo $SHELL
```

I have solutions here for Bash and ZSH. If you are running something else, I'm afraid I can't help you.

### Bash

```bash
# To redraw line after fzf closes (printf '\e[5n')
bind '"\e[0n": redraw-current-line'

_fzf_complete_hashcat() {
	toAdd=""
	if [ -n "${COMP_WORDS[COMP_CWORD]}" ]; then
		toAdd="${COMP_WORDS[COMP_CWORD]} "
		prevArgNo="$COMP_CWORD"
	else
		prevArgNo="$(($COMP_CWORD - 1))"
	fi

	if [[ "${COMP_WORDS[prevArgNo]}" == "-m" || "${COMP_WORDS[prevArgNo]}" == "--hash-type" ]]; then
		local selected
		echo ""
		selected=$(hashcat --example-hashes | awk -v RS="\n\n" -F "\t" '{gsub("\n","\t",$0); print $1 "\t" $2 "\t" $3}' | sed 's/MODE: //; s/TYPE: //' | fzf -d "\t" --header="Mode	Type" --with-nth='1,2' --preview='echo {3}' --preview-window=up:1 --reverse --height 40% | cut -d'	' -f1)
		if [ -n "$selected" ]; then
			printf "\e[5n"
			COMPREPLY=( "$toAdd$selected" )
			return 0
		fi;

	fi


}

complete -F _fzf_complete_hashcat -o default -o bashdefault hashcat
```

In bash, you can provide a function that produces a list of options to tab complete with. For more info on how this works, read `man bash`, there is a section called *Completing*.

The possible completions are put in an array called `COMPREPLY`. If there is only one option, that is automatically inserted into your command line prompt.

The function used to complete hashcat is where the fun stuff happens. There is a bit of logic at the top that is used to determine whether or not we have entered a space after the `-m`. This is important because if there is no space, bash will replace the current word with the completion. It is therefore important that the current word is included in the suggestion.

The rest of the function should be quite self explanatory, it uses the command we built above to make a selection. If a selection is made, `COMPREPLY` is set to an array with only one value, the selected value and (if no space was entered) the argument that was typed. Since the `COMPREPLY` array is of length 1, it is automatically appended to the command line being typed.

The last part of interest are the lines

```bash
bind '"\e[0n": redraw-current-line'
```

and

```bash
printf "\e[5n"
```

These are special escape sequences that are for determining if the terminal is functioning correctly. When `\e5[n` is sent to the terminal, it should respond with `\e[0n`. We listen for this and ask bash to redraw the current line. For more on this, check `man console_codes`.

Unfortunately, this relies on a terminal that supports DSR sequences. Most do, but not all. If you experience a problem where you select a hash and the whole line is replaced by the hash you chose, it is very likely that your terminal emulator doesn't support these codes. A possible work around is to push ctrl-l which will clear your terminal screen and will also cause the current line to be re-drawn. If you do have this problem, you might be interested in switching to Zsh. The ZSH solution doesn't rely on these DSR codes.

### ZSH

```zsh
hashcat-fzf-completion() {
	local tokens cmd append
	setopt localoptions noshwordsplit noksh_arrays noposixbuiltins
	# http://zsh.sourceforge.net/FAQ/zshfaq03.html
	# http://zsh.sourceforge.net/Doc/Release/Expansion.html#Parameter-Expansion-Flags
	tokens=(${(z)LBUFFER})
	if [ ${#tokens} -lt 1 ]; then
		zle ${HCcomplete_default_completion:-expand-or-complete}
		return
	fi
	cmd=${tokens[1]}
	if [[ "$cmd" == "hashcat" ]]; then
		if [[ "${tokens[-1]}" == "-m" || "${tokens[-1]}" == "--hash-type" ]]; then
			append=$(hashcat --example-hashes | awk -v RS="\n\n" -F "\t" '{gsub("\n","\t",$0); print $1 "\t" $2 "\t" $3}' | sed 's/MODE: //; s/TYPE: //' | fzf -d "\t" --header="Mode	Type" --with-nth='1,2' --preview='echo {3}' --preview-window=up:1 --reverse --height=40% | cut -d'	' -f1)
			if [ -n "$append" ]; then
				# Make sure that we are adding a space
				if [[ "${LBUFFER[-1]}" != " " ]]; then
					LBUFFER="${LBUFFER} "
				fi
				LBUFFER="${LBUFFER}${append}"
				zle reset-prompt
				return 0
			fi
			zle reset-prompt
		else
			zle ${HCcomplete_default_completion:-expand-or-complete}
		fi
	else
		zle ${HCcomplete_default_completion:-expand-or-complete}
	fi

}

[ -z "$HCcomplete_default_completion" ] && {
	binding=$(bindkey '^I')
	[[ $binding =~ 'undefined-key' ]] || default_completion=$binding[(s: :w)2]
	unset binding
}
zle     -N   hashcat-fzf-completion
bindkey '^I' hashcat-fzf-completion
fi
```

In ZSH, we do things slightly differently. Instead of using a completion function, we override the binding for the tab key. For legacy reasons, when you push tab, you shell sees Ctrl_I, that is why the binding is for `^I`.

First, we look to see what (if anything) the tab key is bound to and store it in a variable. This is so we can run the old tab completion if it isn't a hashcat mode completion.

Once inside the function, it is very similar. Rather than returning a `COMPREPLY` array, we simply set the `LBUFFER` variable and we can cause a re-draw of the prompt by running `zle reset-prompt`.

Finally, if the command isn't hashcat or the previous argument isn't `-m`, we simply run whatever the tab key was previously bound to.
