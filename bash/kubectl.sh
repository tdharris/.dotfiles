#!/usr/bin/env bash

#################################################################
#
# kubectl Aliases
#
#################################################################

alias kctx="kubectx"
alias kns="kubens"

# other
alias k='kubectl'
alias kl='kubectl logs'
alias kexec='kubectl exec -it'
alias kpf='kubectl port-forward'
alias kaci='kubectl auth can-i'
alias kat='kubectl attach'
alias kapir='kubectl api-resources'
alias kapiv='kubectl api-versions'

# get
alias kg='kubectl get'
alias kgns='kubectl get ns'
alias kgp='kubectl get pods'
alias kgpw='kubectl get pods --output=wide'
alias kgs='kubectl get secrets'
alias kgd='kubectl get deploy'
alias kgrs='kubectl get rs'
alias kgss='kubectl get ss'
alias kgds='kubectl get ds'
alias kgcm='kubectl get configmap'
alias kgcj='kubectl get cronjob'
alias kgj='kubectl get job'
alias kgsvc='kubectl get svc -o wide'
alias kgn='kubectl get no -o wide'
alias kgr='kubectl get roles'
alias kgrb='kubectl get rolebindings'
alias kgcr='kubectl get clusterroles'
alias kgrb='kubectl get clusterrolebindings'
alias kgsa='kubectl get sa'

# edit
alias ke='kubectl edit'
alias kens='kubectl edit ns'
alias kes='kubectl edit secrets'
alias ked='kubectl edit deploy'
alias kers='kubectl edit rs'
alias kess='kubectl edit ss'
alias keds='kubectl edit ds'
alias kesvc='kubectl edit svc'
alias kecm='kubectl edit cm'
alias kecj='kubectl edit cj'
alias ker='kubectl edit roles'
alias kerb='kubectl edit rolebindings'
alias kecr='kubectl edit clusterroles'
alias kerb='kubectl edit clusterrolebindings'
alias kesa='kubectl edit sa'

# describe
alias kd='kubectl describe'
alias kdns='kubectl describe ns'
alias kdp='kubectl describe pod'
alias kds='kubectl describe secrets'
alias kdd='kubectl describe deploy'
alias kdrs='kubectl describe rs'
alias kdss='kubectl describe ss'
alias kdds='kubectl describe ds'
alias kdsvc='kubectl describe svc'
alias kdcm='kubectl describe cm'
alias kdcj='kubectl describe cj'
alias kdj='kubectl describe job'
alias kdsa='kubectl describe sa'
alias kdr='kubectl describe roles'
alias kdrb='kubectl describe rolebindings'
alias kdcr='kubectl describe clusterroles'
alias kdcrb='kubectl describe clusterrolebindings'

# delete
alias kdel='kubectl delete'
alias kdelns='kubectl delete ns'
alias kdels='kubectl delete secrets'
alias kdelp='kubectl delete po'
alias kdeld='kubectl delete deployment'
alias kdelrs='kubectl delete rs'
alias kdelss='kubectl delete ss'
alias kdelds='kubectl delete ds'
alias kdelsvc='kubectl delete svc'
alias kdelcm='kubectl delete cm'
alias kdelcj='kubectl delete cj'
alias kdelj='kubectl delete job'
alias kdelr='kubectl delete roles'
alias kdelrb='kubectl delete rolebindings'
alias kdelcr='kubectl delete clusterroles'
alias kdelrb='kubectl delete clusterrolebindings'
alias kdelsa='kubectl delete sa'

# mock
alias kmock='kubectl create mock -o yaml --dry-run=client'
alias kmockns='kubectl create ns mock -o yaml --dry-run=client'
alias kmockcm='kubectl create cm mock -o yaml --dry-run=client'
alias kmocksa='kubectl create sa mock -o yaml --dry-run=client'

# config
alias kcfg='kubectl config'
alias kcfgv='kubectl config view'
alias kcfgns='kubectl config set-context --current --namespace'
alias kcfgcurrent='kubectl config current-context'
alias kcfggc='kubectl config get-contexts'
alias kcfgsc='kubectl config set-context'
alias kcfguc='kubectl config use-context'
alias kcfgv='kubectl config view'
