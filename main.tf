provider "aws" {
  region = "us-east-1"
}

# Create an AWS VPC
resource "aws_vpc" "vpc" {
    cidr_block = "192.168.0.0/16"
    tags = {
        Name = "vpc"
    }
}

# Create a public subnet
resource "aws_subnet" "public_subnet" {
    vpc_id       = aws_vpc.vpc.id
    cidr_block   = "192.168.1.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true
    tags = {
        Name = "public_subnet"
    }  
}

# Create a private subnet
resource "aws_subnet" "private_subnet" {
    vpc_id       = aws_vpc.vpc.id
    cidr_block   = "192.168.2.0/24"
    availability_zone = "us-east-1a"
    tags = {
        Name = "private_subnet"
    }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.vpc.id
    tags = {
        Name = "internet_gateway"
    }
}  

# Create a route table for the public subnet
resource "aws_route_table" "public_route_table" {
    vpc_id = aws_vpc.vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
    tags = {
        Name = "public_route_table"
    }
}

# # Associate the public route table with the public subnet
resource "aws_route_table_association" "public_route_table_association" {
    subnet_id      = aws_subnet.public_subnet.id
    route_table_id = aws_route_table.public_route_table.id
} 

# Bastion: RDP open (you can later restrict to your IP)
resource "aws_security_group" "bastion_sg" {
  name   = "bastion-sg"
  vpc_id = aws_vpc.vpc.id


egress {
  from_port   = 53
  to_port     = 53
  protocol    = "udp"
  cidr_blocks = ["192.168.0.0/16"]
}
egress {
  from_port   = 53
  to_port     = 53
  protocol    = "tcp"
  cidr_blocks = ["192.168.0.0/16"]
}

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # tighten later to your IP/32
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "bastion-sg" }
}

# Internal Windows servers (PDC, ADC, IIS)
resource "aws_security_group" "internal_sg" {
  name   = "internal-windows-sg"
  vpc_id = aws_vpc.vpc.id

  # RDP from bastion only
  ingress {
    from_port       = 3389
    to_port         = 3389
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # Allow ALL traffic between internal servers
ingress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  self        = true
}

# Allow DNS from bastion
ingress {
  from_port       = 53
  to_port         = 53
  protocol        = "udp"
  security_groups = [aws_security_group.bastion_sg.id]
}
ingress {
  from_port       = 53
  to_port         = 53
  protocol        = "tcp"
  security_groups = [aws_security_group.bastion_sg.id]
}

  
  # AD/DC internal ports (self)
  ingress {
    from_port = 53
    to_port   = 53
    protocol  = "udp"
    self      = true
  }
  ingress {
    from_port = 53
    to_port   = 53
    protocol  = "tcp"
    self      = true
  }
  ingress {
    from_port = 88
    to_port   = 88
    protocol  = "tcp"
    self      = true
  }
  ingress {
    from_port = 389
    to_port   = 389
    protocol  = "tcp"
    self      = true
  }
  ingress {
    from_port = 445
    to_port   = 445
    protocol  = "tcp"
    self      = true
  }
  ingress {
    from_port = 464
    to_port   = 464
    protocol  = "tcp"
    self      = true
  }
  ingress {
    from_port = 3268
    to_port   = 3268
    protocol  = "tcp"
    self      = true
  }
  ingress {
    from_port = 135
    to_port   = 135
    protocol  = "tcp"
    self      = true
  }

  # IIS internal HTTP
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["192.168.0.0/16"]
  }

  # Allow ICMP (ping) from Bastion Host
ingress {
  from_port       = -1
  to_port         = -1
  protocol        = "icmp"
  security_groups = [aws_security_group.bastion_sg.id]
}
# Allow ICMP (ping) between internal machines
ingress {
  from_port = -1
  to_port   = -1
  protocol  = "icmp"
  self      = true
}
ingress {
  from_port   = 49152
  to_port     = 65535
  protocol    = "tcp"
  self        = true
}

# Missing important AD ports
ingress {
  from_port = 88
  to_port   = 88
  protocol  = "udp"
  self      = true
}
ingress {
  from_port = 636
  to_port   = 636
  protocol  = "tcp"
  self      = true
}
ingress {
  from_port = 464
  to_port   = 464
  protocol  = "udp"
  self      = true
}
ingress {
  from_port = 3269
  to_port   = 3269
  protocol  = "tcp"
  self      = true
}

  tags = { Name = "internal-sg" }
}


# Data source: latest Windows Server 2022 AMI
data "aws_ami" "win2022" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }
}

# Bastion host (Windows)
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.win2022.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = null
  user_data = <<-EOF
  <powershell>
  net user Administrator "*Paswword*"
  </powershell>
  EOF
  associate_public_ip_address = true

  tags = { Name = "bastion" }
}

# PDC - Primary Domain Controller
resource "aws_instance" "pdc" {
  ami                         = data.aws_ami.win2022.id
  instance_type               = "t3a.medium"
  subnet_id                   = aws_subnet.private_subnet.id
  vpc_security_group_ids      = [aws_security_group.internal_sg.id]
  key_name                    = null
  associate_public_ip_address = false
  tags = { Name = "PDC" }

  #sheel lw darab
  root_block_device {
    volume_size = 80
  }
  
  user_data = <<-EOF
    <powershell>
    net user Administrator "*Paswword*"
    Set-ExecutionPolicy Unrestricted -Force
    Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools

    $securePass = ConvertTo-SecureString "${var.domain_admin_password}" -AsPlainText -Force
    Install-ADDSForest 
      -DomainName "${var.domain_name}" 
      -SafeModeAdministratorPassword $securePass 
      -InstallDNS 
      -Force:$true
    </powershell>
  EOF
}

# ADC - Additional Domain Controller (replica)
resource "aws_instance" "adc" {
  ami                         = data.aws_ami.win2022.id
  instance_type               = "t3a.medium"
  subnet_id                   = aws_subnet.private_subnet.id
  vpc_security_group_ids      = [aws_security_group.internal_sg.id]
  key_name                    = null
  associate_public_ip_address = false
  tags = { Name = "ADC" }

  #sheel lw darab
  root_block_device {
    volume_size = 80
  }

  user_data = <<-EOF
    <powershell>
    net user Administrator "*Paswword*"
    Set-ExecutionPolicy Unrestricted -Force
    Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools

    $domain = "${var.domain_name}"
    $securePass = ConvertTo-SecureString "${var.domain_admin_password}" -AsPlainText -Force
    $creds = New-Object System.Management.Automation.PSCredential("Administrator", $securePass)

    # Wait until PDC is reachable
    $max = 30
    while ($max -gt 0) {
      if (Test-Connection -ComputerName "PDC.${var.domain_name}" -Count 1 -Quiet) {
        break
      }
      Start-Sleep -Seconds 10
      $max--
    }

    Install-ADDSDomainController 
      -DomainName $domain 
      -Credential $creds 
      -InstallDNS 
      -Force:$true
    </powershell>
  EOF
}

# IIS server: join domain and install IIS
resource "aws_instance" "iis" {
  ami                         = data.aws_ami.win2022.id
  instance_type               = "t3a.medium"
  subnet_id                   = aws_subnet.private_subnet.id   
  vpc_security_group_ids      = [aws_security_group.internal_sg.id]
  key_name                    = null
  associate_public_ip_address = false
  tags = { Name = "IIS" }

  user_data = <<-EOF
    <powershell>
    net user Administrator "*Paswword*"
    Set-ExecutionPolicy Unrestricted -Force

    $domain = "${var.domain_name}"
    $securePass = ConvertTo-SecureString "${var.domain_admin_password}" -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential("$domain\\Administrator", $securePass)

    # Wait for domain controller to be available
    $max = 30
    while ($max -gt 0) {
      if (nltest /dsgetdc:$domain) { break }
      Start-Sleep -Seconds 10
      $max--
    }

    Add-Computer -DomainName $domain -Credential $credential -Restart -Force

    # After restart, install IIS (could be in a scheduled task if race)
    Install-WindowsFeature Web-Server
    </powershell>
  EOF
} 

