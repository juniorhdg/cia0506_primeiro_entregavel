data "aws_ami" "slacko-app" {
    most_recent = true
    owners = ["amazon"]
 
    filter {
        name = "name"
        values = ["Amazon*"]
    }

    filter {
        name = "architecture"
        values = ["x86_64"]
    }

}

data "aws_subnet" "subnet_public" {
   cidr_block = "10.0.102.0/24"
}

# Gerando a chave
# ssh-keygen -C slacko -f slacko
resource "aws_key_pair" "slacko-sshkey" {
    key_name = "slacko-app-key"
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDDyxpmmSPHC77ZzE3W+HGWr1hay6q8ncndoljL5CFfwvKugE5Y2jNESxUvwjQ6gf7OxwmbJp2TNAdpIYdihOcrr/ygiCN99gF5MFZPampo4tPH8v3eRKErmqnf11Ex9sOClLWMTOvKPvgcSoKAkys+jcUliRwkKOJPecJWPNuAJ/lCyU5thuiMI++G8yLxVWW6dQZ0EtbAGxvmDzVWy0VVxsfddCW0/V7KS1kZ1eKN0i96QSUFyU6PM/ejukO6KvIoCSPP5yTh0eUV3zvI5oNb+4to7TrFyxX+c+yajZ4Hkq0x4IQ2mBY/8fhF4E7cFDFgciETbHZ11/Xxk3ao4Sw2Ni7htzMO9If9SGKsNnhWwnWR0xdz2Gj0g0wRnjCggmmmKtLXsuwZ9QDocmZn4/9paYuEj577Y6+e4G1bINw/SdxJ/W0Onj1q/8mh7KFCndwCi8JwuNK2ke99eTu0jXm5oeLX/Tx86BJSTGw19U4gb2PFjsLjRhvx1s6gLW7zg/k= slacko-app"

}

resource "aws_instance" "slacko-app" {
    ami = data.aws_ami.slacko-app.id
    instance_type = "t2.micro"
    subnet_id = data.aws_subnet.subnet_public.id
    associate_public_ip_address = true

    tags = {
        Name = "slacko-app"
    }

    key_name = aws_key_pair.slacko-sshkey.id

    # arquivo de bootstrap  
    user_data = file("ec2.sh")
}

resource "aws_instance" "mongodb" {
    ami = data.aws_ami.slacko-app.id
    instance_type = "t2.small"
    subnet_id = data.aws_subnet.subnet_public.id

    tags = {
        Name = "mongodb"

    }
    key_name = aws_key_pair.slacko-sshkey.id
    user_data = file("mongodb.sh")
}

resource "aws_security_group" "allow-slacko" {
    name = "allow_ssh_http"
    description = "Allow ssh and http port"
    vpc_id = "vpc-036722cf198527689"

    ingress =[
    {
        description = "Allow SSH"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = []
        self = null
        prefix_list_ids = [] 
        security_groups = []
    },
    {
        description = "Allow Http"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = []
        self = null
        prefix_list_ids = [] 
        security_groups = []
    }
]

    egress = [
    {
        description = "Allow all"
        from_port = 0
        to_port = 0
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = []
        self = null
        prefix_list_ids = [] 
        security_groups = []
    }
]

 tags = {
  Name = "allow_ssh_http"
 }
}

resource "aws_security_group" "allow-mongodb" {
    name = "allow_mongodb"
    description = "Allow MongoDB"
    vpc_id = "vpc-036722cf198527689"

    ingress = [
    {
        description = "Allow MongoDB"
        from_port = 27017
        to_port = 27017
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = []
        self = null
        prefix_list_ids = [] 
        security_groups = []
    }
]
    egress = [
    {
        description = "Allow all"
        from_port = 0
        to_port = 0
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = []
        self = null
        prefix_list_ids = [] 
        security_groups = []
    }
]

    tags = {
        Name = "allow_mongodb"
  }
}

resource "aws_network_interface_sg_attachment" "mongodb-sg" {
   security_group_id = aws_security_group.allow-mongodb.id
   network_interface_id = aws_instance.mongodb.primary_network_interface_id
}

resource "aws_network_interface_sg_attachment" "slacko-sg" {
   security_group_id = aws_security_group.allow-slacko.id
   network_interface_id = aws_instance.slacko-app.primary_network_interface_id
}

resource "aws_route53_zone" "slack_zone" {
  name = "iaac0506.com.br"
  vpc {
    vpc_id = "vpc-036722cf198527689"
  }
}

resource "aws_route53_record" "mongodb" {
    zone_id = aws_route53_zone.slack_zone.id
    name = "mongodb.iaac0506.com.br"
    type = "A"
    ttl = "300"
    records = [aws_instance.mongodb.private_ip]
}
