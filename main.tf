resource "tls_private_key" "rsa" {
	algorithm = "RSA"
	rsa_bits  = 4096
}
resource "aws_instance" "service-instance" {
	ami = "ami-01ed8ade75d4eee2f"
	instance_type = "t3.xlarge"
	key_name = aws_key_pair.master-key.key_name
	vpc_security_group_ids = [aws_security_group.service-sg.id]
}

data "aws_vpc" "default" {
	default = true
}

resource "aws_security_group" "service-sg" {
	name = "service-sg"
	description = "Security Group for Serivce Instance"
	vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group_rule" "ssh-access" {
	type = "ingress"
	description = "SSH ingress"
	from_port = 22
	to_port = 22
	protocol = "tcp"
	cidr_blocks = ["0.0.0.0/0"]
	security_group_id = aws_security_group.service-sg.id

	lifecycle { create_before_destroy = true }
}         

resource "aws_security_group_rule" "docker-develop" {
	type = "ingress"
	description = "docker develop ingress"
	from_port = 2375
	to_port = 2375
	protocol = "tcp"
	cidr_blocks = ["0.0.0.0/0"]
	security_group_id = aws_security_group.service-sg.id

	lifecycle { create_before_destroy = true }
}    

resource "aws_security_group_rule" "web-service" {
	type = "ingress"
	description = "web serivice ingress"
	from_port = 8080
	to_port = 8080
	protocol = "tcp"
	cidr_blocks = ["0.0.0.0/0"]
	security_group_id = aws_security_group.service-sg.id

	lifecycle { create_before_destroy = true }
}    

resource "aws_security_group_rule" "service-egress" {
	type = "egress"
	description = "all egress"
	from_port = 0
	to_port = 0
	protocol = -1
	cidr_blocks = ["0.0.0.0/0"]
	security_group_id = aws_security_group.service-sg.id

	lifecycle { create_before_destroy = true }
}    

resource "aws_key_pair" "master-key" {
	key_name   = "master-key.pem"
	public_key = tls_private_key.rsa.public_key_openssh
}

resource "tls_private_key" "rsa-4096-example" {
	algorithm = "RSA"
	rsa_bits  = 4096
}

resource "local_file" "master-key" {
	content  = tls_private_key.rsa.private_key_pem
	filename = "master-key.pem"
}

resource "aws_s3_bucket" "cloudtrail-bucket" {
	bucket = "james-web-service-log-bucket"

	lifecycle { create_before_destroy = true }
}

resource "aws_s3_bucket_policy" "allow-access-write" {
	bucket = aws_s3_bucket.cloudtrail-bucket.id
	policy = data.aws_iam_policy_document.allow-access-for-cloudtrail.json
}

data "aws_iam_policy_document" "allow-access-for-cloudtrail" {
	statement {
		principals {
			type        = "Service"
			identifiers = ["cloudtrail.amazonaws.com"]
		}
		
		actions   = ["s3:GetBucketAcl"]
    	resources = [
			"arn:aws:s3:::james-web-service-log-bucket"
		]
    	effect = "Allow"
	}
	
	statement {
		principals {
			type        = "Service"
			identifiers = ["cloudtrail.amazonaws.com"]
		}

		actions   = ["s3:PutObject"]
    	resources = [
			"arn:aws:s3:::james-web-service-log-bucket/*"
		]
    	effect = "Allow"
	}
}

resource "aws_cloudtrail" "service-log" {
	name = "service.log"
	s3_bucket_name = "james-web-service-log-bucket"

	event_selector {
		read_write_type = "All"
		include_management_events = true
	}
}

