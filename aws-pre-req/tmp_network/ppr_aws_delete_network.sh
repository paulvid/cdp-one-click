    aws ec2 delete-nat-gateway --nat-gateway-id nat-04cb578d6e5f641b5
    aws ec2 delete-nat-gateway --nat-gateway-id nat-02e96afe7eefa0c10
    aws ec2 delete-nat-gateway --nat-gateway-id nat-013c9e305160fb6a7
    sleep 60
    aws ec2 delete-security-group  --group-id sg-07c52f55d864c70a6
    aws ec2 delete-security-group  --group-id sg-0250c7155daa4bd7f

    aws ec2 delete-subnet  --subnet-id subnet-01b33e0f03f6aa621
    aws ec2 delete-subnet  --subnet-id subnet-05b0f49c24f363250
    aws ec2 delete-subnet  --subnet-id subnet-00bbe11bc903af269
    aws ec2 delete-subnet  --subnet-id subnet-0807b8b191a579c1d
    aws ec2 delete-subnet  --subnet-id subnet-0c32f748ce07c396e
    aws ec2 delete-subnet  --subnet-id subnet-00b36e61eb5b529d9


    aws ec2 detach-internet-gateway  --internet-gateway-id igw-046951090a21d684b --vpc-id vpc-0289bc99f4805bb35
    
    aws ec2 delete-route-table  --route-table-id rtb-05d080c7671664160
    aws ec2 delete-route-table  --route-table-id rtb-0ed95b044a5090571
    aws ec2 delete-route-table  --route-table-id rtb-03f0f448139a7da83
    aws ec2 delete-route-table  --route-table-id rtb-01339e63329710aa3

    aws ec2 delete-vpc-endpoint --vpc-endpoint-ids vpce-01d0ca980ff861663 vpce-092eb4e994f06fd30

    aws ec2 delete-vpc  --vpc-id vpc-0289bc99f4805bb35
    aws ec2 delete-internet-gateway  --internet-gateway-id igw-046951090a21d684b 

    
