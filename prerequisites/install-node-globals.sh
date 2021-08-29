#!/bin/bash  

set -e  

read -p "Customer nickname: " NR_CUSTOMER  
while [[ ! $NR_CUSTOMER =~ ^[a-z0-9]*$ ]]; do  
    echo "Input cannot contain non alpha numeric characters!"
    read -p "Customer nickname: " NR_CUSTOMER
done   

read -p "Node name: " NR_NODE_NAME  
while [[ ! $NR_NODE_NAME =~ ^[a-z0-9]*$ ]]; do  
    echo "Input cannot contain non alpha numeric characters!"
    read -p "Node name: " NR_NODE_NAME
done   

echo '***'   
echo 'Customer: '  $NR_CUSTOMER  
echo 'Node Name: '  $NR_NODE_NAME     

echo 'export NR_CUSTOMER='$NR_CUSTOMER >> $HOME/.profile   
echo 'export NR_NODE_NAME='$NR_NODE_NAME >> $HOME/.profile   

source $HOME/.profile  