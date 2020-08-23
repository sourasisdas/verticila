1) Given instance, check its state. Return one of: "noexist, running, stopped, terminated, pending"

    aws ec2 run-instances --image-id ami-173d747e --count 1 --instance-type t1.micro --key-name MyKeyPair --security-groups my-sg
    
2) Given instance, expand its EBS volume (create and use code from aws_ebs.sh) , and reboot to use the expanded volume

3) Given instance, enquire its EBS volume (create and use code from aws_ebs.sh) size/type etc.
