# Terraform Demo

DISCLAIMER: Run this demo at your own risk. The author shall not be responsible for any AWS costs you might incur.

### Steps to Create Infrastructure

1. <a href="https://aws.amazon.com/premiumsupport/knowledge-center/create-and-activate-aws-account/" rel="noopener noreferrer" to target="_blank">Create an AWS account if you don't already have one.</a>

2. <a href="https://docs.aws.amazon.com/general/latest/gr/aws-sec-cred-types.html#access-keys-and-secret-access-keys" rel="noopener noreferrer" to target="_blank">Setup your access key id and secret access key</a> (<a href="https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html" rel="noopener noreferrer" to target="_blank">configuration</a>).

2. <a href="https://learn.hashicorp.com/terraform/getting-started/install.html" rel="noopener noreferrer" to target="_blank">Install Terraform.</a>

3. Clone this repo and `cd` into the clone destination directory.

4. `cd live/dev/base/`

5. `terraform init`

6. `terraform apply` - for now, I've configured the publicly-accessible instances to only accept SSH and HTTP traffic from your own public IP.

7. Wait a few minutes, typically 5 to 10, for the whole process to finish.

8. You can destroy all of the created resources by running `terraform destroy`.

### Configuration

If you need to change the configuration, the configuration files are found in `live/config`. Check the module `source = "config/path"` statements to locate the file you want to edit.

### Manual testing

After running the "Steps to Create Infrastructure", a publicly-accessible ELB should have been created with port 80 open. Check your AWS console (or run the appropriate AWS CLI commands) to get the name of the ELB's public address. Copy and paste that address into your browser and you should see a greeting with the current time.

### Primitive automated testing

You need to install the AWS CLI tool for this to work. `cd live/dev/base/` then run `./test/main.sh /path/to/pem.pem <username>`. The pem file is the file that matches the key/pair specified <a href="https://github.com/michael-software-engr/terrainfra/blob/a53a592801e0875d008499d3b2405f5afda2af40/live/config/dev/module.tf#L2" rel="noopener noreferrer" to target="_blank">here</a> (TODO: don't hard-code, maybe use a variable). `username` is the default username for the AMI used. It's optional. The default value is `ubuntu` since I'm using Ubuntu AMIs. You should pass a `username` argument if you're using an AMI that has a different default user. <a href="https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AccessingInstancesLinux.html" rel="noopener noreferrer" to target="_blank">You also need to setup your SSH to be able to connect to your AWS instances.</a> This script will:

1. SSH into the bastion instance and check if it has Internet connectivity.

2. SSH into each of the auto-scaling group instances using the bastion as a relay. The auto-scaling group instances are not directly accessible from the outside world. Then for each instance, a check if it has Internet connectivity is performed.

3. Lastly, it will check if the expected page is found coming out of the auto-scaling group instances via the ELB's public DNS address.

### AWS Resources

A number of resources will be created after running the "Steps to Create Infrastructure". They include an ELB, an auto-scaling group, and a NAT gateway. Also, a new VPC is created and all the resources are launched inside it.

This list of resources and their configuration may change in the future.

### File Structure

This demo is based on [A Comprehensive Guide to Terraform](https://blog.gruntwork.io/a-comprehensive-guide-to-terraform-b3d32832baca) by [gruntwork.io](https://gruntwork.io/).

Ideally, the `live` and `modules` directories should have their own separate repositories but for now, they are all inside one repository.

The directories where you can do `terraform apply` are located in the sub-directories under `live/dev`. For example, there is a `live/dev/base` for base builds that include a typical production setup composed of a bastion instance and an auto-scaling group. There is also a `live/dev/tiny` that creates only one EC2 instance and one RDS instance for testing a typical web app that uses a database. Note that some of these "executable" files might require variable inputs.

The `modules` directory only contain Terraform module files.

For now, a "local" back-end is used because production level back-ends like "s3" are more complicated to set up and use more (and possibly non-free) resources.

# LICENSE

MIT
