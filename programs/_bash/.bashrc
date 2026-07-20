# Interactive shells only. Non-interactive bash (scripts, bash -c without -i)
# must not pick up aliases like `rm -i` / `cp -i`.
case $- in
  *i*) ;;
  *) return ;;
esac

alias bye=exit
alias cls=clear
alias cp='cp -i'
alias ll='ls -lh --color=auto'
alias ls='ls -asFh --color=auto'
alias mkdir='mkdir -pv'
alias rm='rm -i'
alias where=which
