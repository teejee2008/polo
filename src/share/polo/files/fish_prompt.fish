function fish_prompt
	set_color green
	printf '%s' (date "+%H:%M:%S")
	set_color yellow
	printf ' %s'(basename $PWD)
	set_color normal	
	printf ' $ '
end
