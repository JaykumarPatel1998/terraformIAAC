# Terraform AWS Provisioning

This Terraform code provisions an AWS VPC with subnets and an internet gateway. It also creates a route table to route traffic to the internet.

## Prerequisites

- Terraform >= 1.2.0
- AWS account
- AWS CLI

## Usage

1. Clone the repository.
2. Navigate to the root directory of the repository.
3. Run `terraform init` to initialize the working directory.
4. Run `terraform plan` to create an execution plan.
5. Run `terraform apply` to apply the changes to the infrastructure.

## Variables

| Name | Description |
|------|-------------|
| `vpc_cidr` | The CIDR block for the VPC. |
| `public_subnet_cidr` | The CIDR block for the public subnet. |
| `private_subnet_cidr` | The CIDR block for the private subnet. |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | The ID of the VPC. |
| `public_subnet_id` | The ID of the public subnet. |
| `private_subnet_id` | The ID of the private subnet. |

## Authors

- Jay Patel <jaykumarpatel2710@gmail.com>

## License

This code is licensed under the MIT License. See [LICENSE](LICENSE) for more information.

🚀🚀🚀