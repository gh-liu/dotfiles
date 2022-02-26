# # make WSL use the proxy of host
# hostip=$(cat /etc/resolv.conf | grep nameserver | awk '{ print $2 }')
# wslip=$(hostname -I | awk '{print $1}')

# set_proxy(){
#     port=1081 # set your proxy port
#     PROXY_HTTP="http://${hostip}:${port}"

#     export http_proxy="${PROXY_HTTP}"
#     export HTTP_PROXY="${PROXY_HTTP}"

#     export https_proxy="${PROXY_HTTP}"
#     export HTTPS_proxy="${PROXY_HTTP}"
# }

# unset_proxy(){
#     unset http_proxy
#     unset HTTP_PROXY
#     unset https_proxy
#     unset HTTPS_PROXY
# }

# test_proxy_setting(){
#     echo "Host ip:" ${hostip}
#     echo "WSL ip:" ${wslip}
#     echo "Current proxy:" $https_proxy
# }
#
# setxkbmap -option ctrl:swapcaps

# proxy set and unset
set_proxy(){
    PROXY_HTTP=http://192.168.162.1:1081

    export http_proxy="${PROXY_HTTP}"
    export HTTP_PROXY="${PROXY_HTTP}"

    export https_proxy="${PROXY_HTTP}"
    export HTTPS_proxy="${PROXY_HTTP}"
}
unset_proxy(){
    unset http_proxy
    unset HTTP_PROXY
    unset https_proxy
    unset HTTPS_PROXY
}
set_proxy

# alias go='gotip'
