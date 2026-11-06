function rm --wraps rm --description 'Remove files while protecting system paths'
    if _quickshell_rm_is_protected $argv
        return 1
    end
    command rm $argv
end
