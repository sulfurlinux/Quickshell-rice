function sudo --wraps sudo --description 'Run sudo while protecting recursive rm targets'
    set -l command_index 1
    set -l argument_count (count $argv)
    while test $command_index -le $argument_count
        set -l argument $argv[$command_index]
        switch $argument
            case --
                set command_index (math $command_index + 1)
                break
            case -a -C -D -g -h -p -R -r -t -T -U -u --other-user --close-from --chdir --group --host --prompt --role --type --user --command-timeout
                set command_index (math $command_index + 2)
            case '-*'
                set command_index (math $command_index + 1)
            case '*'
                break
        end
    end

    if test $command_index -le $argument_count
        set -l command_name $argv[$command_index]
        if string match -rq '(^|/)rm$' -- "$command_name"
            set -l rm_args $argv[(math $command_index + 1)..-1]
            if _quickshell_rm_is_protected --root $rm_args
                return 1
            end
        end
    end

    command sudo $argv
end
