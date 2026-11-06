function _quickshell_rm_is_protected --description 'Block rm targets that can damage the system'
    set -l as_root false
    if test "$argv[1]" = --root
        set as_root true
        set -e argv[1]
    end

    set -l after_options false
    set -l targets
    for argument in $argv
        if test "$after_options" = true
            set -a targets "$argument"
        else if test "$argument" = --
            set after_options true
        else if string match -qr '^-' -- "$argument"
            # Ignore rm options, including long and combined flags.
        else
            set -a targets "$argument"
        end
    end

    set -l protected_paths /boot /dev /etc /lib /lib64 /opt /proc /root /run /sbin /srv /sys /usr /var
    set -l exact_paths / /home (command realpath -m -- "$HOME")
    set -l root_only_paths /home /media /mnt /tmp
    for target in $targets
        set -l resolved (command realpath -m -- "$target" 2>/dev/null)
        if test $status -ne 0
            printf 'Blocked rm: could not safely resolve target %s\n' "$target" >&2
            return 0
        end

        if contains -- "$resolved" $exact_paths
            printf 'Blocked rm: %s is a protected system or home path\n' "$resolved" >&2
            return 0
        end
        for protected_path in $protected_paths
            if test "$resolved" = "$protected_path"; or string match -q "$protected_path/*" -- "$resolved"
                printf 'Blocked rm: %s is inside protected system path %s\n' "$resolved" "$protected_path" >&2
                return 0
            end
        end
        if test "$as_root" = true
            for protected_path in $root_only_paths
                if test "$resolved" = "$protected_path" \
                    or string match -q "$protected_path/*" -- "$resolved"
                    printf 'Blocked rm: %s is inside protected root path %s\n' "$resolved" "$protected_path" >&2
                    return 0
                end
            end
        end
    end

    return 1
end
