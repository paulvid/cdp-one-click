
    aws ec2 delete-security-group  --group-id /subscriptions/3b4df54c-3c29-4484-a5bf-a4aee6d2eb0f/resourceGroups/aac-cdp-rg/providers/Microsoft.Network/networkSecurityGroups/aac-knox-nsg
    aws ec2 delete-security-group  --group-id /subscriptions/3b4df54c-3c29-4484-a5bf-a4aee6d2eb0f/resourceGroups/aac-cdp-rg/providers/Microsoft.Network/networkSecurityGroups/aac-default-nsg
    aws ec2 delete-subnet  --subnet-id aac-pub-subnet-1
    aws ec2 delete-subnet  --subnet-id aac-pub-subnet-3
    aws ec2 delete-subnet  --subnet-id aac-pub-subnet-2
    aws ec2 detach-internet-gateway  --internet-gateway-id  --vpc-id null
    aws ec2 delete-route-table  --route-table-id null
    aws ec2 delete-vpc  --vpc-id null
    aws ec2 delete-internet-gateway  --internet-gateway-id 

    
