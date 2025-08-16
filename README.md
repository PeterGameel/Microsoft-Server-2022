# Microsoft-Server-2022
Creating Windows Server 2022 machines on AWS EC2s Using Terraform (IaC): Active Directory, DNS, PDC, ADC, IIS, Forest, Trust, GPO, Users, OUs .....
# Project Title
Microsoft windows Server 2022 on AWS using Terraform as an Infrastructre as a Code (IaC) where the main objective is deploying a secure web-based web application using Active Directory (AD) fro authntication, an IIS web server for hosting the app. Where the app is hosted on Amazon S3 (simple static web page)
# Infrastrucutre Overview 
  -VPC (virtual private cloud)
    -Private Subnet
      - 3 t3a.medium EC2 Machines (will host the windows microsoft server)
    -Public Subent 
      - t2.micro EC2 Machine (will host the Bastion host)
