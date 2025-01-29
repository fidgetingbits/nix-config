# shellcheck disable=SC2148
# shellcheck disable=all

if [ "$(uname -s)" = "Linux" ]; then
	COMPLETION_BASE_DIR=$XDG_RUNTIME_DIR/talon/cache/completions
else
	COMPLETION_BASE_DIR=~/.talon/cache/completions
fi

function list_descendants() {
	local children
	children=$(ps -o pid= --ppid "$1" | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*$//g')
	for pid in $children; do
		list_descendants "$pid"
	done
	echo -n "$children"
}

file_list=(
	talon_zsh_watch
	talon_zsh_folders
	talon_zsh_files
	justfile_commands
	git_branches
	update_git_remotes
)
function cleanup_processes() {
	local children
	children=$(list_descendants $WATCHER_PID)
	if [ -d /proc/$WATCHER_PID ]; then
		kill -9 $WATCHER_PID
	fi
	for pid in $children; do
		if [ -d /proc/"$pid" ]; then
			kill -9 $"pid"
		fi
	done
	for file in "${file_list[@]}"; do
		rm "$COMPLETION_BASE_DIR/$file.$PARENT_PID" 2>/dev/null
	done
}

export TALON_COMPLETION_FILE_LIMIT=100
WATCHER_PID=0
PARENT_PID=0

update_callbacks=(update_folder_list update_file_list update_justfile_commands update_git_branches)
function update_talon_completions() {
	#echo "Updating talon completions for $PWD"

	# Start watching this directory for changes so that we update the list when
	# new folders or files are created
	if ((WATCHER_PID != 0)); then
		cleanup_processes
	fi
	for file in "${file_list[@]}"; do
		#echo "removing $COMPLETION_BASE_DIR/$file.$PARENT_PID"
		rm "$COMPLETION_BASE_DIR/$file.$PARENT_PID" 2>/dev/null
	done

	for callback in "${update_callbacks[@]}"; do
		$callback
	done

	# We have to get the parent pid because once it's in the subshell it
	# doesn't seem to get the same one
	PARENT_PID=$$
	# We execute this in a subshell so that we don't get any of the background
	# job information
	(
		while fswatch -1 --event Created --event Removed --event Renamed "$PWD" >/dev/null; do
			# echo "Detected change in $PWD"
			for callback in "${update_callbacks[@]}"; do
				$callback
			done
		done &
		# Relay the pid back to the parent as it can't get it do to the way we
		# execute the subshell in order to get rid of the job messages
		echo -n $! >"$COMPLETION_BASE_DIR/talon_zsh_watch.$PARENT_PID"
	)
	# Get the pid of the fswatch process
	WATCHER_PID=$(cat $COMPLETION_BASE_DIR/talon_zsh_watch.$$)
	export WATCHER_PID
	trap cleanup TERM HUP INT

	# echo "Started watching for changes: $WATCHER_PID"
}

function update_folder_list() {
	setopt no_nomatch # don't print error if no directories
	# Add folders
	find $PWD -maxdepth 1 -type d -not -path '*/\.*' -not -path '\.' -print | head -n $TALON_COMPLETION_FILE_LIMIT | sed 's/\.\///g' >$COMPLETION_BASE_DIR/talon_zsh_folders.$$.tmp
	# Add symlinks to folders where the folder actually exists
	find $PWD -maxdepth 1 -type l -not -path '*/\.*' -print | head -n $TALON_COMPLETION_FILE_LIMIT | while read -r line; do
		if [[ -d $line ]]; then
			echo "$line" >>$COMPLETION_BASE_DIR/talon_zsh_folders.$$.tmp
		fi
	done
	mv $COMPLETION_BASE_DIR/talon_zsh_folders.$$.tmp $COMPLETION_BASE_DIR/talon_zsh_folders.$$ 2>/dev/null
	# echo "Updated $COMPLETION_BASE_DIR/talon_zsh_folders.$$"
	setopt nomatch
}

function update_file_list() {
	setopt no_nomatch # don't print error if no files
	# Add files
	find $PWD -maxdepth 1 -type f -not -path '*/\.*' -print | head -n $TALON_COMPLETION_FILE_LIMIT | sed 's/\.\///g' >$COMPLETION_BASE_DIR/talon_zsh_files.$$.tmp
	# Add symlinks to files where the file actually exists
	find $PWD -maxdepth 1 -type l -not -path '*/\.*' -print | head -n $TALON_COMPLETION_FILE_LIMIT | while read -r line; do
		if [[ -f $line ]]; then
			echo "$line" >>$COMPLETION_BASE_DIR/talon_zsh_files.$$.tmp
		fi
	done
	mv $COMPLETION_BASE_DIR/talon_zsh_files.$$.tmp $COMPLETION_BASE_DIR/talon_zsh_files.$$ 2>/dev/null
	# echo "Updated $COMPLETION_BASE_DIR/talon_zsh_files.$$"
	setopt nomatch
}

function update_justfile_commands() {
	setopt no_nomatch # don't print error if no justfile
	echo -n "" >$COMPLETION_BASE_DIR/justfile_commands.$$.tmp
	just 2>/dev/null | grep -v "Available recipes" | grep -v "Error:" | while read -r line; do
		echo $line | sed -e s'/#.*//g' >>$COMPLETION_BASE_DIR/justfile_commands.$$.tmp
	done
	mv $COMPLETION_BASE_DIR/justfile_commands.$$.tmp $COMPLETION_BASE_DIR/justfile_commands.$$ 2>/dev/null
	setopt nomatch
}

function update_git_branches() {
	setopt no_nomatch # don't print error if no justfile
	echo -n "" >$COMPLETION_BASE_DIR/git_branches.$$.tmp
	git branch 2>/dev/null | while read -r line; do
		echo $line | sed -e s'/^*//g' >>$COMPLETION_BASE_DIR/git_branches.$$.tmp
	done
	mv $COMPLETION_BASE_DIR/git_branches.$$.tmp $COMPLETION_BASE_DIR/git_branches.$$ 2>/dev/null
	setopt nomatch
}

function update_git_remotes() {
	setopt no_nomatch # don't print error if no justfile
	echo -n "" >$COMPLETION_BASE_DIR/git_remotes.$$.tmp
	git remote 2>/dev/null | while read -r line; do
		echo $line | sed -e s'/^*//g' >>$COMPLETION_BASE_DIR/git_remotes.$$.tmp
	done
	mv $COMPLETION_BASE_DIR/git_remotes.$$.tmp $COMPLETION_BASE_DIR/git_remotes.$$ 2>/dev/null
	setopt nomatch
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd update_talon_completions

mkdir -p $COMPLETION_BASE_DIR 2>/dev/null || true
update_talon_completions
