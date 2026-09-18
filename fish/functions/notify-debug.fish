function notify-debug --wraps=notify-send\ \\\n\ \ \ \ \"Debug\ Notification\"\ \\\n\ \ \ \ \"Click\ me\ whenever\ you\ want.\"\ \\\n\ \ \ \ --action=\"debug=Debug\"\ \\\n\ \ \ \ --wait --description alias\ notify-debug=notify-send\ \\\n\ \ \ \ \"Debug\ Notification\"\ \\\n\ \ \ \ \"Click\ me\ whenever\ you\ want.\"\ \\\n\ \ \ \ --action=\"debug=Debug\"\ \\\n\ \ \ \ --wait
    notify-send \
    "Debug Notification" \
    "Click me whenever you want." \
    --action="debug=Debug" \
    --wait $argv
end
