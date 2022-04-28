# hugo
alias hugos="hugo server -D --bind="0.0.0.0" --baseURL=http://$(hostname -I | awk '{print $1}'):1313"
