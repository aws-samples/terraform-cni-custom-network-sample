# Sample EKS CNI Custom Network with Security Group for Pods

## What does this do?

This repo hosts sample terraform code to create an EKS cluster with CNI custom networking alongside security group for pods.

Resources created are highlighted in following diagram:

![Diagram](/architecture.jpg)

## Steps to run

Checkout this repo and trigger terraform build through:

``` bash

terraform init

terraform apply
```

Type "yes" and the build will start.

### Note

By default, the resources are created in `ap-southeast-2` region.

# Security

See CONTRIBUTING for more information.

# License

This library is licensed under the MIT-0 License. See the LICENSE file.
