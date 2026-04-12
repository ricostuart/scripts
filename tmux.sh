apt update
apt install tmux mc zip htop most configure-debian ncdu pv ltrace strace -y
apt clean

## Start tmux on login
echo -e "if [[ -n \"\$(which tmux)\" ]]; then
\tif [[ -z \"\$TMUX\" ]]; then
\t\ttmux has-session -t login || exec tmux new-session -s login && exec tmux attach-session -d -t login
\tfi
fi" > /etc/profile.d/tmux.sh
